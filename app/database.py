from sqlalchemy import create_engine, Column, Integer, String, Date, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import date
import os

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./my_fridge.db")

# PostgreSQL URL 형식 맞추기 (Railway는 postgres:// 로 시작)
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
else:
    engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    username = Column(String, index=True)
    password_hash = Column(String)
    created_date = Column(Date, default=date.today)
    fcm_token = Column(String, nullable=True)
    subscription_type = Column(String, default="free")  # free/premium/team/vip
    subscription_expires = Column(Date, nullable=True)   # 구독 만료일
    trial_used = Column(Integer, default=0)              # 무료체험 사용 여부
    extra_members = Column(Integer, default=0)           # 팀플랜 추가 인원 수
    fridges = relationship("Fridge", back_populates="owner")

class Fridge(Base):
    __tablename__ = "fridges"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    invite_code = Column(String, unique=True, index=True)
    owner_id = Column(Integer, ForeignKey("users.id"))
    created_date = Column(Date, default=date.today)
    owner = relationship("User", back_populates="fridges")
    members = relationship("FridgeMember", back_populates="fridge")
    ingredients = relationship("Ingredient", back_populates="fridge")

class FridgeMember(Base):
    __tablename__ = "fridge_members"

    id = Column(Integer, primary_key=True, index=True)
    fridge_id = Column(Integer, ForeignKey("fridges.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    fridge = relationship("Fridge", back_populates="members")

class Ingredient(Base):
    __tablename__ = "ingredients"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    registered_date = Column(Date, default=date.today)
    expiry_date = Column(Date, nullable=True)
    consume_date = Column(Date)
    has_expiry_label = Column(Integer, default=0)
    price = Column(Integer, default=0)
    location = Column(String, default="냉장")
    fridge_id = Column(Integer, ForeignKey("fridges.id"), nullable=True)
    fridge = relationship("Fridge", back_populates="ingredients")

class PurchaseHistory(Base):
    __tablename__ = "purchase_history"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    price = Column(Integer, default=0)
    location = Column(String, default="냉장")
    purchased_date = Column(Date, default=date.today)
    fridge_id = Column(Integer, ForeignKey("fridges.id"), nullable=True)

class ShoppingItem(Base):
    __tablename__ = "shopping_items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    quantity = Column(String, default="1개")
    is_purchased = Column(Integer, default=0)
    created_date = Column(Date, default=date.today)
    fridge_id = Column(Integer, ForeignKey("fridges.id"), nullable=True)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def create_tables():
    Base.metadata.create_all(bind=engine)