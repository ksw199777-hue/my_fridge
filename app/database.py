from sqlalchemy import create_engine, Column, Integer, String, Date
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import date, timedelta

DATABASE_URL = "sqlite:///./my_fridge.db"

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class Ingredient(Base):
    __tablename__ = "ingredients"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    registered_date = Column(Date, default=date.today)
    expiry_date = Column(Date, nullable=True)  # 유통기한 (없을 수 있음)
    consume_date = Column(Date)  # 소비기한
    has_expiry_label = Column(Integer, default=0)  # 유통기한 표시 있는지 0/1
    price = Column(Integer, default=0)
    location = Column(String, default="냉장")
    pythonclass PurchaseHistory(Base):
    __tablename__ = "purchase_history"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    price = Column(Integer, default=0)
    location = Column(String, default="냉장")
    purchased_date = Column(Date, default=date.today)
    
class ShoppingItem(Base):
    __tablename__ = "shopping_items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    quantity = Column(Integer, default=1)
    is_purchased = Column(Integer, default=0)  # 0: 미구매, 1: 구매완료
    created_date = Column(Date, default=date.today)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def create_tables():
    Base.metadata.create_all(bind=engine)