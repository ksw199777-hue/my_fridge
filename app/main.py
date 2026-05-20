from fastapi import FastAPI, UploadFile, File, Depends
from sqlalchemy.orm import Session
from dotenv import load_dotenv
from datetime import date, timedelta
from app.database import get_db, create_tables, Ingredient, ShoppingItem
from app.ai import recognize_ingredients, recommend_recipes, recognize_from_screenshot
from pydantic import BaseModel

load_dotenv()

app = FastAPI(title="나만의 냉장고 API")

@app.on_event("startup")
def startup():
    create_tables()

@app.get("/")
def root():
    return {"message": "나만의 냉장고 API 시작!"}

@app.post("/recognize")
async def recognize(file: UploadFile = File(...), db: Session = Depends(get_db)):
    image_bytes = await file.read()
    ingredients = recognize_ingredients(image_bytes)
    
    saved = []
    for item in ingredients:
        ingredient = Ingredient(
            name=item["name"],
            registered_date=date.today(),
            expiry_date=date.today() + timedelta(days=item["expiry_days"])
        )
        db.add(ingredient)
        db.commit()
        db.refresh(ingredient)
        saved.append({
            "id": ingredient.id,
            "name": ingredient.name,
            "registered_date": ingredient.registered_date,
            "expiry_date": ingredient.expiry_date
        })
    
    return {"ingredients": saved}

@app.get("/ingredients")
def get_ingredients(db: Session = Depends(get_db)):
    ingredients = db.query(Ingredient).all()
    return {"ingredients": [
        {
            "id": i.id,
            "name": i.name,
            "registered_date": i.registered_date,
            "expiry_date": i.expiry_date,
            "d_day": (i.expiry_date - date.today()).days
        }
        for i in ingredients
    ]}

@app.get("/recipes")
def get_recipes(db: Session = Depends(get_db)):
    ingredients = db.query(Ingredient).all()
    if not ingredients:
        return {"message": "냉장고에 재료가 없어요!", "recipes": []}
    
    recipes = recommend_recipes(ingredients)
    return {"recipes": recipes}

@app.get("/ingredients/expiring")
def get_expiring_ingredients(days: int = 3, db: Session = Depends(get_db)):
    today = date.today()
    expiring = db.query(Ingredient).filter(
        Ingredient.expiry_date <= today + timedelta(days=days),
        Ingredient.expiry_date >= today
    ).all()
    
    expired = db.query(Ingredient).filter(
        Ingredient.expiry_date < today
    ).all()
    
    return {
        "expiring_soon": [
            {
                "id": i.id,
                "name": i.name,
                "expiry_date": i.expiry_date,
                "d_day": (i.expiry_date - today).days
            }
            for i in expiring
        ],
        "expired": [
            {
                "id": i.id,
                "name": i.name,
                "expiry_date": i.expiry_date,
                "d_day": (i.expiry_date - today).days
            }
            for i in expired
        ]
    }

@app.delete("/ingredients/{ingredient_id}")
def delete_ingredient(ingredient_id: int, db: Session = Depends(get_db)):
    ingredient = db.query(Ingredient).filter(Ingredient.id == ingredient_id).first()
    
    if not ingredient:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="재료를 찾을 수 없어요")
    
    db.delete(ingredient)
    db.commit()
    
    return {"message": f"{ingredient.name} 삭제됐어요!"}

@app.post("/recognize/screenshot")
async def recognize_screenshot(file: UploadFile = File(...), db: Session = Depends(get_db)):
    image_bytes = await file.read()
    ingredients = recognize_from_screenshot(image_bytes)
    
    saved = []
    for item in ingredients:
        ingredient = Ingredient(
            name=item["name"],
            registered_date=date.today(),
            expiry_date=date.today() + timedelta(days=item["expiry_days"])
        )
        db.add(ingredient)
        db.commit()
        db.refresh(ingredient)
        saved.append({
            "id": ingredient.id,
            "name": ingredient.name,
            "quantity": item.get("quantity", 1),
            "registered_date": ingredient.registered_date,
            "expiry_date": ingredient.expiry_date
        })
    
    return {"ingredients": saved}

class IngredientCreate(BaseModel):
    name: str
    expiry_days: int
    price: int = 0
    location: str = "냉장"  # 냉장/냉동/실온

@app.post("/ingredients")
def create_ingredient(item: IngredientCreate, db: Session = Depends(get_db)):
    ingredient = Ingredient(
        name=item.name,
        registered_date=date.today(),
        expiry_date=date.today() + timedelta(days=item.expiry_days),
        price=item.price,
        location=item.location
    )
    db.add(ingredient)
    db.commit()
    db.refresh(ingredient)
    
    return {
        "id": ingredient.id,
        "name": ingredient.name,
        "registered_date": ingredient.registered_date,
        "expiry_date": ingredient.expiry_date,
        "price": ingredient.price,
        "location": ingredient.location
    }

class IngredientUpdate(BaseModel):
    name: str = None
    expiry_days: int = None
    price: int = None
    location: str = None

@app.put("/ingredients/{ingredient_id}")
def update_ingredient(ingredient_id: int, item: IngredientUpdate, db: Session = Depends(get_db)):
    ingredient = db.query(Ingredient).filter(Ingredient.id == ingredient_id).first()
    
    if not ingredient:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="재료를 찾을 수 없어요")
    
    if item.name is not None:
        ingredient.name = item.name
    if item.expiry_days is not None:
        ingredient.expiry_date = date.today() + timedelta(days=item.expiry_days)
    if item.price is not None:
        ingredient.price = item.price
    if item.location is not None:
        ingredient.location = item.location
    
    db.commit()
    db.refresh(ingredient)
    
    return {
        "id": ingredient.id,
        "name": ingredient.name,
        "registered_date": ingredient.registered_date,
        "expiry_date": ingredient.expiry_date,
        "price": ingredient.price,
        "location": ingredient.location
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
            "price": i.price,
            "location": i.location,
            "d_day": (i.expiry_date - date.today()).days
        }
        for i in ingredients
    ]}

@app.get("/expenses/monthly")
def get_monthly_expenses(year: int, month: int, db: Session = Depends(get_db)):
    from sqlalchemy import extract
    
    ingredients = db.query(Ingredient).filter(
        extract('year', Ingredient.registered_date) == year,
        extract('month', Ingredient.registered_date) == month
    ).all()
    
    total = sum(i.price for i in ingredients)
    
    by_location = {}
    for i in ingredients:
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
                "registered_date": i.registered_date
            }
            for i in ingredients
        ]
    }
