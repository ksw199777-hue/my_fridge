from fastapi import FastAPI, UploadFile, File
from dotenv import load_dotenv
from app.ai import recognize_ingredients

load_dotenv()

app = FastAPI(title="나만의 냉장고 API")

@app.get("/")
def root():
    return {"message": "나만의 냉장고 API 시작!"}

@app.post("/recognize")
async def recognize(file: UploadFile = File(...)):
    image_bytes = await file.read()
    ingredients = recognize_ingredients(image_bytes)
    return {"ingredients": ingredients}