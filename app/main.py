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

load_dotenv()

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
    else:
        cred = credentials.Certificate("app/firebase-service-account.json")
    firebase_admin.initialize_app(cred)
    
    scheduler = BackgroundScheduler()
    scheduler.add_job(check_expiry, CronTrigger(hour=9, minute=0))
    scheduler.start()

@app.get("/")
def root():
    return {"message": "나만의 냉장고 API 시작!"}

@app.post("/recognize")
async def recognize(file: UploadFile = File(...), fridge_id: int = None, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    image_bytes = await file.read()
    ingredients = recognize_ingredients(image_bytes)
    saved = []
    for item in ingredients:
        expiry_days = item.get("expiry_days")
        consume_days = item.get("consume_days") or 7
        has_expiry_label = item.get("has_expiry_label", False)
        ingredient = Ingredient(
            name=item["name"],
            registered_date=date.today(),
            expiry_date=date.today() + timedelta(days=expiry_days) if expiry_days else None,
            consume_date=date.today() + timedelta(days=consume_days),
            has_expiry_label=1 if has_expiry_label else 0,
            price=0,
            location="냉장"
        )
        db.add(ingredient)
        db.commit()
        db.refresh(ingredient)
        save_purchase_history(db, ingredient)
        saved.append({
            "id": ingredient.id,
            "name": ingredient.name,
            "registered_date": ingredient.registered_date,
            "expiry_date": ingredient.expiry_date,
            "consume_date": ingredient.consume_date,
            "has_expiry_label": ingredient.has_expiry_label,
            "price": ingredient.price,
            "location": ingredient.location
        })
    return {
        "ingredients": saved,
        "message": "유통기한 표시가 없는 재료는 오늘 기준으로 소비기한을 산출했어요! 냉장고 탭에서 수정 가능해요 ✏️"
    }

@app.post("/recognize/screenshot")
async def recognize(file: UploadFile = File(...), fridge_id: int = None, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    image_bytes = await file.read()
    ingredients = recognize_from_screenshot(image_bytes)
    saved = []
    for item in ingredients:
        consume_days = item.get("consume_days") or 7
        ingredient = Ingredient(
            name=item["name"],
            registered_date=date.today(),
            expiry_date=None,
            consume_date=date.today() + timedelta(days=consume_days),
            has_expiry_label=0,
            price=item.get("price", 0),
            location="냉장"
        )
        db.add(ingredient)
        db.commit()
        db.refresh(ingredient)
        save_purchase_history(db, ingredient)
        saved.append({
            "id": ingredient.id,
            "name": ingredient.name,
            "quantity": item.get("quantity", 1),
            "registered_date": ingredient.registered_date,
            "expiry_date": ingredient.expiry_date,
            "consume_date": ingredient.consume_date,
            "has_expiry_label": ingredient.has_expiry_label,
            "price": ingredient.price,
            "location": ingredient.location
        })
    return {
        "ingredients": saved,
        "message": "유통기한 표시가 없어 오늘을 기준으로 소비기한을 산출했어요! 냉장고 탭에서 수정 가능해요 ✏️"
    }

@app.post("/recognize/receipt")
async def recognize(file: UploadFile = File(...), fridge_id: int = None, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    image_bytes = await file.read()
    ingredients = recognize_receipt(image_bytes)
    saved = []
    for item in ingredients:
        consume_days = item.get("consume_days") or 7
        ingredient = Ingredient(
            name=item["name"],
            registered_date=date.today(),
            expiry_date=None,
            consume_date=date.today() + timedelta(days=consume_days),
            has_expiry_label=0,
            price=item.get("price", 0),
            location="냉장"
        )
        db.add(ingredient)
        db.commit()
        db.refresh(ingredient)
        save_purchase_history(db, ingredient)
        saved.append({
            "id": ingredient.id,
            "name": ingredient.name,
            "quantity": item.get("quantity", 1),
            "registered_date": ingredient.registered_date,
            "expiry_date": ingredient.expiry_date,
            "consume_date": ingredient.consume_date,
            "has_expiry_label": ingredient.has_expiry_label,
            "price": ingredient.price,
            "location": ingredient.location
        })
    return {
        "ingredients": saved,
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
        # 내 모든 냉장고 재료
        owned_fridge_ids = [f.id for f in db.query(Fridge).filter(Fridge.owner_id == current_user.id).all()]
        member_fridge_ids = [m.fridge_id for m in db.query(FridgeMember).filter(FridgeMember.user_id == current_user.id).all()]
        all_fridge_ids = owned_fridge_ids + member_fridge_ids
        query = query.filter(Ingredient.fridge_id.in_(all_fridge_ids))
    
    ingredients = query.all()
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

@app.delete("/ingredients/{ingredient_id}")
def delete_ingredient(ingredient_id: int, db: Session = Depends(get_db)):
    ingredient = db.query(Ingredient).filter(Ingredient.id == ingredient_id).first()
    if not ingredient:
        raise HTTPException(status_code=404, detail="재료를 찾을 수 없어요")
    db.delete(ingredient)
    db.commit()
    return {"message": f"{ingredient.name} 삭제됐어요!"}

class IngredientCreate(BaseModel):
    name: str
    expiry_days: int = None
    consume_days: int = 7
    price: int = 0
    location: str = "냉장"
    has_expiry_label: bool = False

@app.post("/ingredients")
def create_ingredient(item: IngredientCreate, fridge_id: int, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
    ingredient = Ingredient(
        name=item.name,
        registered_date=date.today(),
        expiry_date=date.today() + timedelta(days=item.expiry_days) if item.expiry_days else None,
        consume_date=date.today() + timedelta(days=item.consume_days),
        has_expiry_label=1 if item.has_expiry_label else 0,
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
        "fridge_id": ingredient.fridge_id
    }
class IngredientUpdate(BaseModel):
    name: str = None
    expiry_days: int = None
    consume_days: int = None
    price: int = None
    location: str = None
    has_expiry_label: bool = None

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
def get_recipes(db: Session = Depends(get_db)):
    ingredients = db.query(Ingredient).all()
    if not ingredients:
        return {"message": "냉장고에 재료가 없어요!", "recipes": []}
    recipes = recommend_recipes(ingredients)
    return {"recipes": recipes}

class RecipeChatRequest(BaseModel):
    message: str

@app.post("/recipe/chat")
async def recipe_chat(request: RecipeChatRequest, db: Session = Depends(get_db)):
    ingredients = db.query(Ingredient).all()
    ingredient_names = ", ".join([i.name for i in ingredients]) if ingredients else "없음"
    response = chat_recipe(request.message, ingredient_names)
    return response

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
        db.query(PurchaseHistory).filter(
            PurchaseHistory.name == ingredient.name
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
def estimate_shopping_price(db: Session = Depends(get_db)):
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
    
    new_user = User(
        email=user.email,
        username=user.username,
        password_hash=hash_password(user.password),
        created_date=date.today()
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
        "user": {"id": db_user.id, "email": db_user.email, "username": db_user.username}
    }

@app.get("/auth/me")
def get_me(current_user: User = Depends(require_user)):
    return {"id": current_user.id, "email": current_user.email, "username": current_user.username}

# 냉장고 관련 API
@app.post("/fridges")
def create_fridge(fridge: FridgeCreate, current_user: User = Depends(require_user), db: Session = Depends(get_db)):
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