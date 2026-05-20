from fastapi import FastAPI, UploadFile, File, Depends
from sqlalchemy.orm import Session
from dotenv import load_dotenv
from datetime import date, timedelta
from app.ai import recognize_ingredients
from app.database import get_db, create_tables, Ingredient
from app.ai import recognize_ingredients, recommend_recipes

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