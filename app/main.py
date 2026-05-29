from fastapi import FastAPI, UploadFile, File, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from dotenv import load_dotenv
from datetime import date, timedelta
from app.ai import recognize_ingredients, recommend_recipes, recognize_from_screenshot, recognize_expiry_date, recognize_receipt, chat_recipe, estimate_price
from pydantic import BaseModel
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from app.auth import hash_password, verify_password, create_access_token, get_current_user, require_user
from app.database import get_db, create_tables, Ingredient, ShoppingItem, PurchaseHistory, User, Fridge, FridgeMember
import random
import string
import firebase_admin
from firebase_admin import credentials, messaging
from typing import Optional
import os
import smtplib
import random
import string
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail
from app.auth import hash_password
import requests as req

load_dotenv()

# 플랜별 제한 설정
PLAN_LIMITS = {
    "free":    {"fridges": 1, "members": 1},
    "premium": {"fridges": 2, "members": 2},
    "team":    {"fridges": 3, "members": 4},  # extra_members로 최대 6명까지
    "vip":     {"fridges": 999, "members": 999},
}

def get_max_members(user: User) -> int:
    if user.subscription_type == "team":
        return 4 + user.extra_members  # 기본 4명 + 추가 인원
    return PLAN_LIMITS.get(user.subscription_type, {"members": 1})["members"]

def check_ai_permission(current_user: User, fridge_id: int, db: Session):
    """AI 기능 사용 권한 체크"""
    if current_user.subscription_type == "vip":
        return True  # VIP는 본인 포함 멤버 전원 가능
    
    if current_user.subscription_type in ["premium", "team"]:
        return True  # 구독자 본인만 가능
    
    # free면 냉장고 오너가 vip인지 체크
    if fridge_id:
        fridge = db.query(Fridge).filter(Fridge.id == fridge_id).first()
        if fridge:
            owner = db.query(User).filter(User.id == fridge.owner_id).first()
            if owner and owner.subscription_type == "vip":
                return True
    
    return False

def check_fridge_limit(current_user: User, db: Session):
    """냉장고 대수 제한 체크"""
    max_fridges = PLAN_LIMITS.get(current_user.subscription_type, {"fridges": 1})["fridges"]
    current_count = db.query(Fridge).filter(Fridge.owner_id == current_user.id).count()
    if current_count >= max_fridges:
        raise HTTPException(status_code=403, detail=f"현재 플랜에서는 냉장고를 {max_fridges}대까지만 만들 수 있어요!")

def check_member_limit(fridge: Fridge, current_user: User, db: Session):
    """공유 인원 제한 체크"""
    owner = db.query(User).filter(User.id == fridge.owner_id).first()
    max_members = get_max_members(owner)
    current_count = db.query(FridgeMember).filter(FridgeMember.fridge_id == fridge.id).count()
    if current_count >= max_members - 1:  # 오너 포함이라 -1
        raise HTTPException(status_code=403, detail=f"현재 플랜에서는 최대 {max_members}명까지 공유할 수 있어요!")

app = FastAPI(title="나만의 냉장고 API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def save_purchase_history(db: Session, ingredient: Ingredient):
    if ingredient.price > 0:
        history = PurchaseHistory(
            name=ingredient.name,
            price=ingredient.price,
            location=ingredient.location,
            purchased_date=date.today()
        )
        db.add(history)
        db.commit()

def check_expiry():
    from app.database import SessionLocal
    db = SessionLocal()
    today = date.today()
    
    users = db.query(User).filter(User.fcm_token != None).all()
    
    for user in users:
        owned_fridge_ids = [f.id for f in db.query(Fridge).filter(Fridge.owner_id == user.id).all()]
        member_fridge_ids = [m.fridge_id for m in db.query(FridgeMember).filter(FridgeMember.user_id == user.id).all()]
        all_fridge_ids = owned_fridge_ids + member_fridge_ids
        
        expiring = db.query(Ingredient).filter(
            Ingredient.fridge_id.in_(all_fridge_ids),
            Ingredient.consume_date <= today + timedelta(days=3),
            Ingredient.consume_date >= today
        ).all()
        
        expired = db.query(Ingredient).filter(
            Ingredient.fridge_id.in_(all_fridge_ids),
            Ingredient.consume_date < today
        ).all()
        
        if expiring:
            names = ", ".join([i.name for i in expiring[:3]])
            try:
                messaging.send(messaging.Message(
                    notification=messaging.Notification(
                        title="⚠️ 소비기한 임박!",
                        body=f"{names} 등 {len(expiring)}개 재료가 3일 이내예요!",
                    ),
                    token=user.fcm_token,
                ))
            except Exception as e:
                print(f"알림 전송 실패: {e}")
        
        if expired:
            names = ", ".join([i.name for i in expired[:3]])
            try:
                messaging.send(messaging.Message(
                    notification=messaging.Notification(
                        title="❌ 소비기한 만료!",
                        body=f"{names} 등 {len(expired)}개 재료가 만료됐어요!",
                    ),
                    token=user.fcm_token,
                ))
            except Exception as e:
                print(f"알림 전송 실패: {e}")
    
    db.close()

@app.on_event("startup")
def startup():
    create_tables()
    
    # Firebase 초기화
    import json
    firebase_creds = os.getenv("FIREBASE_CREDENTIALS")
    if firebase_creds:
        cred = credentials.Certificate(json.loads(firebase_creds))
        firebase_admin.initialize_app(cred)
    
    scheduler = BackgroundScheduler()
    scheduler.add_job(check_expiry, CronTrigger(hour=9, minute=0, timezone="Asia/Seoul"))
    scheduler.start()
    
@app.get("/")
def root():
    return {"message": "나만의 냉장고 API 시작!"}

@app.post("/recognize")
async def recognize_camera(file: UploadFile = File(...), fridge_id: int = None, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    image_bytes = await file.read()
    if not fridge_id:
        my_fridge = db.query(Fridge).filter(Fridge.owner_id == current_user.id).first()
        if not my_fridge:
            raise HTTPException(status_code=404, detail="냉장고가 없어요!")
        fridge_id = my_fridge.id
    ingredients = recognize_ingredients(image_bytes)
    return {
        "ingredients": [
            {
                "name": item["name"],
                "expiry_days": item.get("expiry_days"),
                "consume_days": item.get("consume_days") or 7,
                "has_expiry_label": item.get("has_expiry_label", False),
                "price": 0,
                "location": "냉장",
                "storage_type": "냉장",
            }
            for item in ingredients
        ],
        "message": "유통기한 표시가 없는 재료는 오늘 기준으로 소비기한을 산출했어요! 냉장고 탭에서 수정 가능해요 ✏️"
    }
    
@app.post("/recognize/screenshot")
async def recognize_screenshot(file: UploadFile = File(...), fridge_id: int = None, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    image_bytes = await file.read()
    if not fridge_id:
        my_fridge = db.query(Fridge).filter(Fridge.owner_id == current_user.id).first()
        if not my_fridge:
            raise HTTPException(status_code=404, detail="냉장고가 없어요!")
        fridge_id = my_fridge.id
    ingredients = recognize_from_screenshot(image_bytes)
    return {
        "ingredients": [
            {
                "name": item["name"],
                "expiry_days": None,
                "consume_days": item.get("consume_days") or 7,
                "consume_date": item.get("consume_date"),
                "has_expiry_label": False,
                "price": item.get("price", 0),
                "location": "냉장",
                "storage_type": "냉장",
                "quantity": item.get("quantity", 1),
            }
            for item in ingredients
        ],
        "message": "유통기한 표시가 없어 오늘을 기준으로 소비기한을 산출했어요! 냉장고 탭에서 수정 가능해요 ✏️"
    }

@app.post("/recognize/receipt")
async def recognize_receipt_upload(file: UploadFile = File(...), fridge_id: int = None, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    image_bytes = await file.read()
    if not fridge_id:
        my_fridge = db.query(Fridge).filter(Fridge.owner_id == current_user.id).first()
        if not my_fridge:
            raise HTTPException(status_code=404, detail="냉장고가 없어요!")
        fridge_id = my_fridge.id
    ingredients = recognize_receipt(image_bytes)
    return {
        "ingredients": [
            {
                "name": item["name"],
                "expiry_days": None,
                "consume_days": item.get("consume_days") or 7,
                "consume_date": item.get("consume_date"),
                "has_expiry_label": False,
                "price": item.get("price", 0),
                "location": "냉장",
                "storage_type": "냉장",
                "quantity": item.get("quantity", 1),
            }
            for item in ingredients
        ],
        "message": "유통기한 표시가 없어 오늘을 기준으로 소비기한을 산출했어요! 냉장고 탭에서 수정 가능해요 ✏️"
    }
    
@app.get("/ingredients")
def get_ingredients(
    fridge_id: int = None,
    current_user: User = Depends(require_user),
    db: Session = Depends(get_db)
):
    query = db.query(Ingredient)
    if fridge_id:
        query = query.filter(Ingredient.fridge_id == fridge_id)
    else:
        owned_fridge_ids = [f.id for f in db.query(Fridge).filter(Fridge.owner_id == current_user.id).all()]
        member_fridge_ids = [m.fridge_id for m in db.query(FridgeMember).filter(FridgeMember.user_id == current_user.id).all()]
        all_fridge_ids = owned_fridge_ids + member_fridge_ids
        query = query.filter(Ingredient.fridge_id.in_(all_fridge_ids))
    
    # 이름순 → 날짜순 정렬 (같은 재료끼리 묶임)
    ingredients = query.order_by(Ingredient.name, Ingredient.registered_date).all()
    
    return {"ingredients": [
        {
            "id": i.id,
            "name": i.name,
            "registered_date": str(i.registered_date),
            "expiry_date": str(i.expiry_date) if i.expiry_date else None,
            "consume_date": str(i.consume_date),
            "has_expiry_label": i.has_expiry_label,
            "price": i.price,
            "location": i.location,
            "storage_type": i.storage_type,
            "fridge_id": i.fridge_id,
            "d_day": (i.consume_date - date.today()).days
        }
        for i in ingredients
    ]}

@app.get("/ingredients/expiring")
def get_expiring_ingredients(days: int = 3, db: Session = Depends(get_db)):
    today = date.today()
    expiring = db.query(Ingredient).filter(
        Ingredient.consume_date <= today + timedelta(days=days),
        Ingredient.consume_date >= today
    ).all()
    expired = db.query(Ingredient).filter(
        Ingredient.consume_date < today
    ).all()
    return {
        "expiring_soon": [
            {
                "id": i.id,
                "name": i.name,
                "consume_date": i.consume_date,
                "price": i.price,
                "location": i.location,
                "d_day": (i.consume_date - today).days
            }
            for i in expiring
        ],
        "expired": [
            {
                "id": i.id,
                "name": i.name,
                "consume_date": i.consume_date,
                "price": i.price,
                "location": i.location,
                "d_day": (i.consume_date - today).days
            }
            for i in expired
        ]
    }

@app.get("/ingredients/search")
def search_ingredients(keyword: str, db: Session = Depends(get_db)):
    ingredients = db.query(Ingredient).filter(
        Ingredient.name.contains(keyword)
    ).all()
    if not ingredients:
        return {"message": f"'{keyword}' 검색 결과가 없어요", "ingredients": []}
    return {"ingredients": [
        {
            "id": i.id,
            "name": i.name,
            "registered_date": i.registered_date,
            "expiry_date": i.expiry_date,
            "consume_date": i.consume_date,
            "has_expiry_label": i.has_expiry_label,
            "price": i.price,
            "location": i.location,
            "d_day": (i.consume_date - date.today()).days
        }
        for i in ingredients
    ]}
class IngredientCreate(BaseModel):
    name: str
    expiry_days: Optional[int] = None
    consume_days: int = 7
    price: int = 0
    location: str = "냉장"
    has_expiry_label: bool = False
    storage_type: str = "냉장"

@app.post("/ingredients")
def create_ingredient(item: IngredientCreate, fridge_id: int, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    check_fridge_limit(current_user, db)
    
    # 소비기한 비워두면 AI 자동 산출
    consume_days = item.consume_days
    if consume_days == 7:
        try:
            from app.ai import get_consume_days_by_storage
            consume_days = get_consume_days_by_storage(item.name, item.storage_type)
        except Exception:
            defaults = {"냉장": 7, "냉동": 90, "실온": 3}
            consume_days = defaults.get(item.storage_type, 7)
            
     # 같은 이름 재료 중복 체크 후 숫자 붙이기
    existing = db.query(Ingredient).filter(
        Ingredient.fridge_id == fridge_id,
        Ingredient.name.like(f"{item.name}%")
        ).all()

    if existing:
        existing_names = [i.name for i in existing]
        if item.name in existing_names:
            counter = 2
            while f"{item.name}{counter}" in existing_names:
                counter += 1
            item.name = f"{item.name}{counter}"
    
    ingredient = Ingredient(
        name=item.name,
        registered_date=date.today(),
        expiry_date=date.today() + timedelta(days=item.expiry_days) if item.expiry_days else None,
        consume_date=date.today() + timedelta(days=consume_days),
        has_expiry_label=1 if item.has_expiry_label else 0,
        storage_type=item.storage_type,
        price=item.price,
        location=item.location,
        fridge_id=fridge_id
    )
    db.add(ingredient)
    db.commit()
    db.refresh(ingredient)
    save_purchase_history(db, ingredient)
    return {
        "id": ingredient.id,
        "name": ingredient.name,
        "registered_date": ingredient.registered_date,
        "expiry_date": ingredient.expiry_date,
        "consume_date": ingredient.consume_date,
        "has_expiry_label": ingredient.has_expiry_label,
        "price": ingredient.price,
        "location": ingredient.location,
        "storage_type": ingredient.storage_type,
        "fridge_id": ingredient.fridge_id
    }
class IngredientUpdate(BaseModel):
    name: str = None
    expiry_days: int = None
    consume_days: int = None
    price: int = None
    location: str = None
    has_expiry_label: bool = None
    storage_type: str = None

@app.put("/ingredients/{ingredient_id}")
def update_ingredient(ingredient_id: int, item: IngredientUpdate, db: Session = Depends(get_db)):
    ingredient = db.query(Ingredient).filter(Ingredient.id == ingredient_id).first()
    if not ingredient:
        raise HTTPException(status_code=404, detail="재료를 찾을 수 없어요")
    if item.name is not None:
        ingredient.name = item.name
    if item.expiry_days is not None:
        ingredient.expiry_date = date.today() + timedelta(days=item.expiry_days)
    if item.consume_days is not None:
        ingredient.consume_date = date.today() + timedelta(days=item.consume_days)
    if item.price is not None:
        ingredient.price = item.price
    if item.location is not None:
        ingredient.location = item.location
    if item.has_expiry_label is not None:
        ingredient.has_expiry_label = 1 if item.has_expiry_label else 0
    if item.storage_type is not None:
        ingredient.storage_type = item.storage_type
        # 보관방법 바뀌면 소비기한 자동 재계산
        from app.ai import get_consume_days_by_storage
        new_days = get_consume_days_by_storage(ingredient.name, item.storage_type)
        ingredient.consume_date = date.today() + timedelta(days=new_days)
    db.commit()
    db.refresh(ingredient)
    return {
        "id": ingredient.id,
        "name": ingredient.name,
        "registered_date": ingredient.registered_date,
        "expiry_date": ingredient.expiry_date,
        "consume_date": ingredient.consume_date,
        "has_expiry_label": ingredient.has_expiry_label,
        "price": ingredient.price,
        "location": ingredient.location
    }

@app.get("/recipes")
def get_recipes(fridge_id: int = None, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    if not check_ai_permission(current_user, fridge_id, db):
        raise HTTPException(status_code=403, detail="프리미엄 기능이에요! 업그레이드가 필요해요 ⭐")
    
    ingredients = db.query(Ingredient).all()
    if not ingredients:
        return {"message": "냉장고에 재료가 없어요!", "recipes": []}
    recipes = recommend_recipes(ingredients)
    return {"recipes": recipes}

class RecipeChatRequest(BaseModel):
    message: str

@app.post("/recipe/chat")
async def recipe_chat(request: RecipeChatRequest, fridge_id: int = None, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    if not check_ai_permission(current_user, fridge_id, db):
        raise HTTPException(status_code=403, detail="프리미엄 기능이에요! 업그레이드가 필요해요 ⭐")
    
    ingredients = db.query(Ingredient).all()
    ingredient_names = ", ".join([i.name for i in ingredients]) if ingredients else "없음"
    result = chat_recipe(request.message, ingredient_names)
    return result

class ShoppingItemCreate(BaseModel):
    name: str
    quantity: str = "1개"

@app.post("/shopping")
def add_shopping_item(item: ShoppingItemCreate, fridge_id: int = None, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    shopping_item = ShoppingItem(
        name=item.name,
        quantity=item.quantity,
        created_date=date.today(),
        fridge_id=fridge_id
    )
    db.add(shopping_item)
    db.commit()
    db.refresh(shopping_item)
    return {"id": shopping_item.id, "name": shopping_item.name, "quantity": shopping_item.quantity, "is_purchased": shopping_item.is_purchased}

@app.get("/shopping")
def get_shopping_list(fridge_id: int = None, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    query = db.query(ShoppingItem).filter(ShoppingItem.is_purchased == 0)
    if fridge_id:
        query = query.filter(ShoppingItem.fridge_id == fridge_id)
    items = query.all()
    return {"shopping_list": [
        {"id": i.id, "name": i.name, "quantity": i.quantity}
        for i in items
    ]}

@app.put("/shopping/{item_id}/purchased")
def mark_purchased(item_id: int, db: Session = Depends(get_db)):
    item = db.query(ShoppingItem).filter(ShoppingItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="아이템을 찾을 수 없어요")
    item.is_purchased = 1
    db.commit()
    return {"message": f"{item.name} 구매 완료!"}

@app.delete("/ingredients/{ingredient_id}")
def delete_ingredient(ingredient_id: int, delete_history: bool = False, db: Session = Depends(get_db)):
    ingredient = db.query(Ingredient).filter(Ingredient.id == ingredient_id).first()
    if not ingredient:
        raise HTTPException(status_code=404, detail="재료를 찾을 수 없어요")
    
    if delete_history:
        # 이름 + 등록날짜 기준으로 해당 기록만 삭제
        db.query(PurchaseHistory).filter(
            PurchaseHistory.name == ingredient.name,
            PurchaseHistory.purchased_date == ingredient.registered_date
        ).delete()
    
    db.delete(ingredient)
    db.commit()
    return {"message": f"{ingredient.name} 삭제됐어요!"}

@app.get("/expenses/monthly")
def get_monthly_expenses(year: int, month: int, db: Session = Depends(get_db)):
    from sqlalchemy import extract
    histories = db.query(PurchaseHistory).filter(
        extract('year', PurchaseHistory.purchased_date) == year,
        extract('month', PurchaseHistory.purchased_date) == month
    ).all()
    total = sum(i.price for i in histories)
    by_location = {}
    for i in histories:
        if i.location not in by_location:
            by_location[i.location] = 0
        by_location[i.location] += i.price
    return {
        "year": year,
        "month": month,
        "total_expense": total,
        "by_location": by_location,
        "ingredients": [
            {
                "name": i.name,
                "price": i.price,
                "location": i.location,
                "registered_date": i.purchased_date
            }
            for i in histories
        ]
    }

@app.get("/expenses/history")
def get_expense_history(db: Session = Depends(get_db)):
    from sqlalchemy import extract, func
    monthly_data = db.query(
        extract('year', PurchaseHistory.purchased_date).label('year'),
        extract('month', PurchaseHistory.purchased_date).label('month'),
        func.sum(PurchaseHistory.price).label('total')
    ).group_by('year', 'month').order_by('year', 'month').all()
    result = []
    for row in monthly_data:
        result.append({
            "year": int(row.year),
            "month": int(row.month),
            "total": int(row.total or 0)
        })
    if len(result) >= 2:
        diff = result[-1]['total'] - result[-2]['total']
    else:
        diff = 0
    return {
        "history": result,
        "diff_from_last_month": diff
    }

@app.get("/statistics")
def get_statistics(db: Session = Depends(get_db)):
    today = date.today()
    all_ingredients = db.query(Ingredient).all()
    total_count = len(all_ingredients)
    total_spent = sum(i.price for i in all_ingredients)
    expired = [i for i in all_ingredients if i.consume_date < today]
    expired_count = len(expired)
    expired_value = sum(i.price for i in expired)
    expiring_soon = [i for i in all_ingredients if today <= i.consume_date <= today + timedelta(days=3)]
    by_location = {}
    for i in all_ingredients:
        if i.location not in by_location:
            by_location[i.location] = {"count": 0, "total_price": 0}
        by_location[i.location]["count"] += 1
        by_location[i.location]["total_price"] += i.price
    saved_value = sum(i.price for i in all_ingredients if i.consume_date >= today)
    return {
        "total": {
            "count": total_count,
            "total_spent": total_spent
        },
        "expired": {
            "count": expired_count,
            "value": expired_value,
            "ingredients": [{"name": i.name, "consume_date": i.consume_date, "price": i.price} for i in expired]
        },
        "expiring_soon": {
            "count": len(expiring_soon),
            "ingredients": [{"name": i.name, "consume_date": i.consume_date, "d_day": (i.consume_date - today).days} for i in expiring_soon]
        },
        "by_location": by_location,
        "saved_value": saved_value
    }

@app.get("/shopping/estimate")
def estimate_shopping_price(fridge_id: int = None, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    if not check_ai_permission(current_user, fridge_id, db):
        raise HTTPException(status_code=403, detail="프리미엄 기능이에요! 업그레이드가 필요해요 ⭐")
    
    items = db.query(ShoppingItem).filter(ShoppingItem.is_purchased == 0).all()
    if not items:
        return {"message": "쇼핑 목록이 비어있어요!", "items": [], "total": 0}
    
    item_list = [{"name": i.name, "quantity": i.quantity} for i in items]
    result = estimate_price(item_list)
    return result

# 회원가입/로그인 모델
class UserRegister(BaseModel):
    email: str
    username: str
    password: str

class UserLogin(BaseModel):
    email: str
    password: str

# 냉장고 생성 모델
class FridgeCreate(BaseModel):
    name: str

def generate_invite_code():
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))

@app.post("/auth/register")
def register(user: UserRegister, db: Session = Depends(get_db)):
    # 이메일 중복 체크
    existing = db.query(User).filter(User.email == user.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="이미 사용중인 이메일이에요")
    
    VIP_EMAILS = ["ksw9777@naver.com"]
    subscription = "vip" if user.email in VIP_EMAILS else "free"
    
    new_user = User(
        email=user.email,
        username=user.username,
        password_hash=hash_password(user.password),
        created_date=date.today(),
        subscription_type=subscription
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # 기본 냉장고 자동 생성
    fridge = Fridge(
        name="우리집 냉장고",
        invite_code=generate_invite_code(),
        owner_id=new_user.id,
        created_date=date.today()
    )
    db.add(fridge)
    db.commit()
    
    token = create_access_token(new_user.id)
    return {
        "token": token,
        "user": {"id": new_user.id, "email": new_user.email, "username": new_user.username}
    }

@app.post("/auth/login")
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.email == user.email).first()
    if not db_user or not verify_password(user.password, db_user.password_hash):
        raise HTTPException(status_code=401, detail="이메일 또는 비밀번호가 틀렸어요")
    
    token = create_access_token(db_user.id)
    return {
        "token": token,
        "user": {
            "id": db_user.id,
            "email": db_user.email,
            "username": db_user.username,
            "subscription_type": db_user.subscription_type
        }
    }

@app.get("/auth/me")
def get_me(current_user: User = Depends(require_user)):
    return {
        "id": current_user.id,
        "email": current_user.email,
        "username": current_user.username,
        "subscription_type": current_user.subscription_type,
        "subscription_expires": current_user.subscription_expires,
        "extra_members": current_user.extra_members,
        "trial_used": current_user.trial_used
    }

# 냉장고 관련 API
@app.post("/fridges")
def create_fridge(fridge: FridgeCreate, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    check_fridge_limit(current_user, db)
    new_fridge = Fridge(
        name=fridge.name,
        invite_code=generate_invite_code(),
        owner_id=current_user.id,
        created_date=date.today()
    )
    db.add(new_fridge)
    db.commit()
    db.refresh(new_fridge)
    return {"id": new_fridge.id, "name": new_fridge.name, "invite_code": new_fridge.invite_code}

@app.get("/fridges")
def get_fridges(current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    # 내가 만든 냉장고 + 초대받은 냉장고
    owned = db.query(Fridge).filter(Fridge.owner_id == current_user.id).all()
    member_fridge_ids = [m.fridge_id for m in db.query(FridgeMember).filter(FridgeMember.user_id == current_user.id).all()]
    shared = db.query(Fridge).filter(Fridge.id.in_(member_fridge_ids)).all()
    
    all_fridges = owned + shared
    return {"fridges": [
        {"id": f.id, "name": f.name, "invite_code": f.invite_code, "is_owner": f.owner_id == current_user.id}
        for f in all_fridges
    ]}

@app.post("/fridges/join")
def join_fridge(invite_code: str, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    fridge = db.query(Fridge).filter(Fridge.invite_code == invite_code).first()
    if not fridge:
        raise HTTPException(status_code=404, detail="초대 코드가 올바르지 않아요")
    
    check_member_limit(fridge, current_user, db)
    
    # 이미 멤버인지 체크
    existing = db.query(FridgeMember).filter(
        FridgeMember.fridge_id == fridge.id,
        FridgeMember.user_id == current_user.id
    ).first()
    if existing or fridge.owner_id == current_user.id:
        raise HTTPException(status_code=400, detail="이미 참여중인 냉장고예요")
    
    member = FridgeMember(fridge_id=fridge.id, user_id=current_user.id)
    db.add(member)
    db.commit()
    return {"message": f"{fridge.name}에 참여했어요!"}

@app.delete("/shopping/{item_id}")
def delete_shopping_item(item_id: int, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    item = db.query(ShoppingItem).filter(ShoppingItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="아이템을 찾을 수 없어요")
    db.delete(item)
    db.commit()
    return {"message": f"{item.name} 삭제됐어요!"}

@app.delete("/fridges/{fridge_id}")
def delete_fridge(fridge_id: int, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    fridge = db.query(Fridge).filter(Fridge.id == fridge_id, Fridge.owner_id == current_user.id).first()
    if not fridge:
        raise HTTPException(status_code=404, detail="냉장고를 찾을 수 없어요")
    
    # 냉장고 안 재료도 같이 삭제
    db.query(Ingredient).filter(Ingredient.fridge_id == fridge_id).delete()
    db.query(ShoppingItem).filter(ShoppingItem.fridge_id == fridge_id).delete()
    db.delete(fridge)
    db.commit()
    return {"message": f"{fridge.name} 삭제됐어요!"}

class FCMTokenUpdate(BaseModel):
    fcm_token: str

@app.post("/auth/fcm-token")
def update_fcm_token(token: FCMTokenUpdate, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    current_user.fcm_token = token.fcm_token
    db.commit()
    return {"message": "FCM 토큰 저장됐어요!"}

class SubscriptionUpdate(BaseModel):
    subscription_type: str  # premium / team / vip
    extra_members: int = 0  # 팀플랜 추가 인원

@app.post("/auth/subscription")
def update_subscription(data: SubscriptionUpdate, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    valid_plans = ["free", "premium", "team", "vip"]
    if data.subscription_type not in valid_plans:
        raise HTTPException(status_code=400, detail="올바르지 않은 플랜이에요")
    
    # 팀플랜 추가 인원 검증 (0~2명만 가능, 최대 6명)
    if data.subscription_type == "team" and not (0 <= data.extra_members <= 2):
        raise HTTPException(status_code=400, detail="추가 인원은 0~2명만 가능해요")
    
    from datetime import date
    from dateutil.relativedelta import relativedelta
    
    # 무료체험 처리
    if current_user.trial_used == 0:
        current_user.subscription_expires = date.today() + relativedelta(months=2)  # 1개월 무료 + 1개월
        current_user.trial_used = 1
    else:
        current_user.subscription_expires = date.today() + relativedelta(months=1)
    
    current_user.subscription_type = data.subscription_type
    current_user.extra_members = data.extra_members
    db.commit()
    
    return {
        "message": f"{data.subscription_type} 플랜으로 변경됐어요!",
        "subscription_type": current_user.subscription_type,
        "subscription_expires": current_user.subscription_expires,
        "trial_used": current_user.trial_used
    }
    
class StorageTypeRequest(BaseModel):
    name: str
    storage_type: str

@app.post("/ingredients/calculate-consume-days")
def calculate_consume_days(request: StorageTypeRequest, current_user: User = Depends(require_user)):
    from app.ai import get_consume_days_by_storage
    days = get_consume_days_by_storage(request.name, request.storage_type)
    return {"consume_days": days}

@app.get("/fridges/{fridge_id}/members")
def get_fridge_members(fridge_id: int, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    fridge = db.query(Fridge).filter(Fridge.id == fridge_id).first()
    if not fridge:
        raise HTTPException(status_code=404, detail="냉장고를 찾을 수 없어요")
    
    # 오너 정보
    owner = db.query(User).filter(User.id == fridge.owner_id).first()
    members = db.query(FridgeMember).filter(FridgeMember.fridge_id == fridge_id).all()
    
    member_list = [{
        "id": owner.id,
        "username": owner.username,
        "email": owner.email,
        "is_owner": True
    }]
    
    for m in members:
        user = db.query(User).filter(User.id == m.user_id).first()
        if user:
            member_list.append({
                "id": user.id,
                "username": user.username,
                "email": user.email,
                "is_owner": False
            })
    
    return {
        "fridge_id": fridge_id,
        "fridge_name": fridge.name,
        "invite_code": fridge.invite_code if fridge.owner_id == current_user.id else None,
        "is_owner": fridge.owner_id == current_user.id,
        "members": member_list
    }

@app.delete("/fridges/{fridge_id}/members/{user_id}")
def remove_fridge_member(fridge_id: int, user_id: int, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    fridge = db.query(Fridge).filter(Fridge.id == fridge_id, Fridge.owner_id == current_user.id).first()
    if not fridge:
        raise HTTPException(status_code=403, detail="권한이 없어요")
    
    member = db.query(FridgeMember).filter(
        FridgeMember.fridge_id == fridge_id,
        FridgeMember.user_id == user_id
    ).first()
    if not member:
        raise HTTPException(status_code=404, detail="멤버를 찾을 수 없어요")
    
    db.delete(member)
    db.commit()
    return {"message": "멤버를 내보냈어요!"}

class BudgetCreate(BaseModel):
    year: int
    month: int
    budget: int
    memo: str = ""

@app.post("/budget")
def set_budget(data: BudgetCreate, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    from app.database import Budget
    budget = db.query(Budget).filter(
        Budget.user_id == current_user.id,
        Budget.year == data.year,
        Budget.month == data.month
    ).first()
    if budget:
        budget.budget = data.budget
        budget.memo = data.memo
    else:
        budget = Budget(
            user_id=current_user.id,
            year=data.year,
            month=data.month,
            budget=data.budget,
            memo=data.memo
        )
        db.add(budget)
    db.commit()
    return {"message": "예산이 저장됐어요!"}

@app.get("/budget")
def get_budget(year: int, month: int, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    from app.database import Budget
    budget = db.query(Budget).filter(
        Budget.user_id == current_user.id,
        Budget.year == year,
        Budget.month == month
    ).first()
    return {
        "budget": budget.budget if budget else 0,
        "memo": budget.memo if budget else ""
    }
    
# 임시 비밀번호 저장 (실제로는 Redis 사용하지만 간단히 딕셔너리로)
reset_tokens = {}

@app.post("/auth/forgot-password")
def forgot_password(email: str, db: Session = Depends(get_db)):
    try:
        user = db.query(User).filter(User.email == email).first()
        if not user:
            raise HTTPException(status_code=404, detail="등록되지 않은 이메일이에요")
        
        temp_password = ''.join(random.choices(string.digits, k=6))
        reset_tokens[email] = temp_password
        
        sg = SendGridAPIClient(os.getenv("SENDGRID_API_KEY"))
        message = Mail(
            from_email=os.getenv("SENDGRID_FROM_EMAIL"),
            to_emails=email,
            subject='[나만의 냉장고] 임시 비밀번호 안내',
            plain_text_content=f'임시 비밀번호: {temp_password}\n\n앱에서 임시 비밀번호로 로그인 후 비밀번호를 변경해주세요.'
        )
        sg.send(message)
        print("이메일 발송 성공")
        return {"message": "임시 비밀번호를 이메일로 발송했어요!"}
    except Exception as e:
        print(f"에러 발생: {e}")
        raise HTTPException(status_code=500, detail=str(e))
class ResetPasswordRequest(BaseModel):
    email: str
    temp_password: str
    new_password: str

@app.post("/auth/reset-password")
def reset_password(data: ResetPasswordRequest, db: Session = Depends(get_db)):
    if reset_tokens.get(data.email) != data.temp_password:
        raise HTTPException(status_code=400, detail="임시 비밀번호가 올바르지 않아요")
    
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없어요")
    
    user.password_hash = hash_password(data.new_password)
    db.commit()
    
    del reset_tokens[data.email]
    return {"message": "비밀번호가 변경됐어요!"}

@app.get("/recipe/search")
def search_recipes(query: str, current_user: User = Depends(require_user)):
    client_id = os.environ.get("NAVER_CLIENT_ID")
    client_secret = os.environ.get("NAVER_CLIENT_SECRET")
    
    url = "https://openapi.naver.com/v1/search/blog.json"
    headers = {
        "X-Naver-Client-Id": client_id,
        "X-Naver-Client-Secret": client_secret,
    }
    params = {
        "query": f"{query} 레시피",
        "display": 10,
        "sort": "sim"
    }
    
    response = req.get(url, headers=headers, params=params)
    data = response.json()
    
    return {
        "items": [
            {
                "title": item["title"].replace("<b>", "").replace("</b>", ""),
                "link": item["link"],
                "description": item["description"].replace("<b>", "").replace("</b>", ""),
                "bloggername": item["bloggername"],
            }
            for item in data.get("items", [])
        ]
    }