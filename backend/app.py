"""
IntizomAI — Mobil ilova uchun REST API.

Railway'dagi MAVJUD PostgreSQL bazasiga ulanadi (bot bilan BIR XUL DB).
FastAPI + SQLAlchemy async.
"""
from __future__ import annotations

import os
from contextlib import asynccontextmanager
from datetime import date, datetime, timedelta
from typing import Optional

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException
from jose import JWTError, jwt
from pydantic import BaseModel
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

load_dotenv()

# ── Config ────────────────────────────────────────────────
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "productivity_bot")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASS = os.getenv("DB_PASS", "")
DATABASE_URL = f"postgresql+asyncpg://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# JWT — ilova auth uchun (bot tomonidan generatsiya qilinadi)
JWT_SECRET = os.getenv("JWT_SECRET", "change-me-in-production")
JWT_ALGORITHM = "HS256"

# ── DB Engine ─────────────────────────────────────────────
engine = create_async_engine(DATABASE_URL, pool_size=10, max_overflow=20)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)


async def get_db():
    async with SessionLocal() as session:
        yield session


# ── Auth dependency ───────────────────────────────────────
async def get_current_user_id(
    authorization: str = Header(...),
    db: AsyncSession = Depends(get_db),
) -> int:
    """Bearer token'dan user_id ajratib oladi."""
    token = authorization.removeprefix("Bearer ").strip()
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = payload.get("user_id")
        if user_id is None:
            raise HTTPException(401, "Invalid token")
        return int(user_id)
    except JWTError:
        raise HTTPException(401, "Invalid token")


# ── Bot tomonidan token generatsiya qilish funksiyasi ────
def create_app_token(user_id: int, telegram_id: int) -> str:
    """Bot /login_app komandasi shu funksiyani chaqiradi."""
    payload = {
        "user_id": user_id,
        "telegram_id": telegram_id,
        "exp": datetime.utcnow() + timedelta(days=365),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


# ── SQLAlchemy modellari (mavjud jadvallardan) ────────────
# Bot'dagi modellarga to'g'ridan-to'g'ri ulansa ham bo'ladi,
# lekin API alohida deployment bo'lgani uchun lightweight
# reflection ishlatamiz.
from sqlalchemy import (
    BigInteger, Boolean, Column, Date, DateTime, Integer,
    String, Text, ForeignKey,
)
from sqlalchemy.orm import DeclarativeBase, relationship


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    telegram_id = Column(BigInteger, unique=True)
    full_name = Column(String(255))
    display_name = Column(String(255))
    username = Column(String(255))
    photo_url = Column(String(512))
    custom_photo_url = Column(String(1048576))
    streak = Column(Integer, default=0)
    total_score = Column(Integer, default=0)
    xp = Column(Integer, default=0)
    level = Column(Integer, default=1)
    longest_streak = Column(Integer, default=0)
    streak_freezes = Column(Integer, default=0)
    discipline_score = Column(Integer, default=50)
    weekly_xp = Column(Integer, default=0)
    perfect_days = Column(Integer, default=0)
    is_premium = Column(Boolean, default=False)
    premium_until = Column(DateTime)
    onboarded = Column(Boolean, default=False)
    rank_title = Column(String(40))
    avatar_emoji = Column(String(8), default="🌱")
    referral_count = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    notifications_enabled = Column(Boolean, default=True)
    created_at = Column(DateTime)
    last_active = Column(DateTime)
    ai_msgs_date = Column(Date)
    ai_msgs_count = Column(Integer, default=0)


class Plan(Base):
    __tablename__ = "plans"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    title = Column(String(500))
    description = Column(Text)
    scheduled_time = Column(String(5))
    plan_date = Column(Date)
    status = Column(String(10), default="pending")
    score_value = Column(Integer, default=5)
    created_by_user_id = Column(Integer)
    notified_at = Column(DateTime)


class Habit(Base):
    __tablename__ = "habits"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    title = Column(String(300))
    description = Column(Text)
    icon = Column(String(8), default="✅")
    reminder_time = Column(String(5))
    frequency = Column(String(10), default="daily")
    weekdays = Column(String(20))
    duration_type = Column(String(12), default="permanent")
    target_days = Column(Integer)
    start_date = Column(Date)
    sort_order = Column(Integer, default=0)
    archived = Column(Boolean, default=False)


class HabitLog(Base):
    __tablename__ = "habit_logs"
    id = Column(Integer, primary_key=True)
    habit_id = Column(Integer, ForeignKey("habits.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    log_date = Column(Date)


class Goal(Base):
    __tablename__ = "goals"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    title = Column(String(500))
    description = Column(Text)
    goal_type = Column(String(10), default="yearly")
    period = Column(String(10))
    completed = Column(Boolean, default=False)


# ── FastAPI ───────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await engine.dispose()


app = FastAPI(title="IntizomAI Mobile API", version="1.0.0", lifespan=lifespan)


# ── Pydantic sxemalar ────────────────────────────────────
class PlanCreate(BaseModel):
    title: str
    description: Optional[str] = None
    scheduled_time: Optional[str] = None
    plan_date: str


class PlanStatusUpdate(BaseModel):
    status: str  # "done" | "pending" | "failed"


class HabitCreate(BaseModel):
    title: str
    description: Optional[str] = None
    icon: str = "✅"
    frequency: str = "daily"
    weekdays: Optional[str] = None
    reminder_time: Optional[str] = None


class GoalCreate(BaseModel):
    title: str
    description: Optional[str] = None
    goal_type: str = "yearly"
    period: Optional[str] = None


class ProfileUpdate(BaseModel):
    display_name: Optional[str] = None
    notifications_enabled: Optional[bool] = None


class CoachMessage(BaseModel):
    message: str


# ── ROUTES ────────────────────────────────────────────────

# ── User / Profile ──
@app.get("/api/v1/user/profile")
async def get_profile(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(404, "User not found")
    return _user_to_dict(user)


@app.patch("/api/v1/user/profile")
async def update_profile(
    body: ProfileUpdate,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(404, "User not found")
    if body.display_name is not None:
        user.display_name = body.display_name
    if body.notifications_enabled is not None:
        user.notifications_enabled = body.notifications_enabled
    await db.commit()
    return _user_to_dict(user)


@app.get("/api/v1/user/dashboard")
async def get_dashboard(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(404, "User not found")

    today = date.today()
    plans_q = await db.execute(
        select(Plan).where(and_(Plan.user_id == user_id, Plan.plan_date == today))
    )
    plans = plans_q.scalars().all()
    done = sum(1 for p in plans if p.status == "done")

    return {
        "user": _user_to_dict(user),
        "today_plans_done": done,
        "today_plans_total": len(plans),
    }


# ── Plans ──
@app.get("/api/v1/plans/today")
async def get_today_plans(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    today = date.today()
    res = await db.execute(
        select(Plan)
        .where(and_(Plan.user_id == user_id, Plan.plan_date == today))
        .order_by(Plan.scheduled_time.asc().nullslast(), Plan.id)
    )
    return [_plan_to_dict(p) for p in res.scalars().all()]


@app.get("/api/v1/plans")
async def get_plans(
    date_str: str = "",
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    target = date.fromisoformat(date_str) if date_str else date.today()
    res = await db.execute(
        select(Plan)
        .where(and_(Plan.user_id == user_id, Plan.plan_date == target))
        .order_by(Plan.scheduled_time.asc().nullslast(), Plan.id)
    )
    return [_plan_to_dict(p) for p in res.scalars().all()]


@app.post("/api/v1/plans")
async def create_plan(
    body: PlanCreate,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    plan = Plan(
        user_id=user_id,
        title=body.title,
        description=body.description,
        scheduled_time=body.scheduled_time,
        plan_date=date.fromisoformat(body.plan_date),
        status="pending",
        score_value=5,
    )
    db.add(plan)
    await db.commit()
    await db.refresh(plan)
    return _plan_to_dict(plan)


@app.patch("/api/v1/plans/{plan_id}/status")
async def set_plan_status(
    plan_id: int,
    body: PlanStatusUpdate,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    plan = await db.get(Plan, plan_id)
    if not plan or plan.user_id != user_id:
        raise HTTPException(404, "Plan not found")
    if body.status not in ("done", "pending", "failed"):
        raise HTTPException(400, "Invalid status")
    plan.status = body.status
    await db.commit()
    return _plan_to_dict(plan)


@app.delete("/api/v1/plans/{plan_id}")
async def delete_plan(
    plan_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    plan = await db.get(Plan, plan_id)
    if not plan or plan.user_id != user_id:
        raise HTTPException(404, "Plan not found")
    await db.delete(plan)
    await db.commit()
    return {"ok": True}


@app.post("/api/v1/plans/{plan_id}/move-tomorrow")
async def move_plan_tomorrow(
    plan_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    plan = await db.get(Plan, plan_id)
    if not plan or plan.user_id != user_id:
        raise HTTPException(404, "Plan not found")
    plan.plan_date = plan.plan_date + timedelta(days=1)
    plan.status = "pending"
    await db.commit()
    return _plan_to_dict(plan)


# ── Habits ──
@app.get("/api/v1/habits")
async def get_habits(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    today = date.today()
    res = await db.execute(
        select(Habit)
        .where(Habit.user_id == user_id)
        .order_by(Habit.sort_order, Habit.id)
    )
    habits = res.scalars().all()

    # Bugun belgilanganlarni tekshirish
    logs_res = await db.execute(
        select(HabitLog.habit_id).where(
            and_(HabitLog.user_id == user_id, HabitLog.log_date == today)
        )
    )
    done_ids = {row[0] for row in logs_res.all()}

    result = []
    for h in habits:
        d = _habit_to_dict(h)
        d["today_done"] = h.id in done_ids
        result.append(d)
    return result


@app.post("/api/v1/habits")
async def create_habit(
    body: HabitCreate,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    habit = Habit(
        user_id=user_id,
        title=body.title,
        description=body.description,
        icon=body.icon,
        frequency=body.frequency,
        weekdays=body.weekdays,
        reminder_time=body.reminder_time,
    )
    db.add(habit)
    await db.commit()
    await db.refresh(habit)
    d = _habit_to_dict(habit)
    d["today_done"] = False
    return d


@app.post("/api/v1/habits/{habit_id}/toggle")
async def toggle_habit(
    habit_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    habit = await db.get(Habit, habit_id)
    if not habit or habit.user_id != user_id:
        raise HTTPException(404, "Habit not found")

    today = date.today()
    existing = await db.execute(
        select(HabitLog).where(
            and_(HabitLog.habit_id == habit_id, HabitLog.log_date == today)
        )
    )
    log = existing.scalar_one_or_none()
    if log:
        await db.delete(log)
        today_done = False
    else:
        db.add(HabitLog(habit_id=habit_id, user_id=user_id, log_date=today))
        today_done = True
    await db.commit()

    d = _habit_to_dict(habit)
    d["today_done"] = today_done
    return d


@app.patch("/api/v1/habits/{habit_id}")
async def update_habit(
    habit_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    habit = await db.get(Habit, habit_id)
    if not habit or habit.user_id != user_id:
        raise HTTPException(404, "Habit not found")
    habit.archived = True
    await db.commit()
    d = _habit_to_dict(habit)
    d["today_done"] = False
    return d


@app.delete("/api/v1/habits/{habit_id}")
async def delete_habit(
    habit_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    habit = await db.get(Habit, habit_id)
    if not habit or habit.user_id != user_id:
        raise HTTPException(404, "Habit not found")
    await db.delete(habit)
    await db.commit()
    return {"ok": True}


# ── Goals ──
@app.get("/api/v1/goals")
async def get_goals(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    res = await db.execute(
        select(Goal)
        .where(Goal.user_id == user_id)
        .order_by(Goal.id.desc())
    )
    return [_goal_to_dict(g) for g in res.scalars().all()]


@app.post("/api/v1/goals")
async def create_goal(
    body: GoalCreate,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    goal = Goal(
        user_id=user_id,
        title=body.title,
        description=body.description,
        goal_type=body.goal_type,
        period=body.period,
    )
    db.add(goal)
    await db.commit()
    await db.refresh(goal)
    return _goal_to_dict(goal)


@app.post("/api/v1/goals/{goal_id}/toggle")
async def toggle_goal(
    goal_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    goal = await db.get(Goal, goal_id)
    if not goal or goal.user_id != user_id:
        raise HTTPException(404, "Goal not found")
    goal.completed = not goal.completed
    await db.commit()
    return _goal_to_dict(goal)


@app.delete("/api/v1/goals/{goal_id}")
async def delete_goal(
    goal_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    goal = await db.get(Goal, goal_id)
    if not goal or goal.user_id != user_id:
        raise HTTPException(404, "Goal not found")
    await db.delete(goal)
    await db.commit()
    return {"ok": True}


# ── Coach ──
@app.get("/api/v1/coach/smart-message")
async def get_smart_message(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Dashboardda ko'rsatiladigan motivatsion xabar."""
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(404)

    msg = _smart_message(user)
    return {"message": msg}


# ── Auth endpoint (bot chaqiradi) ──
class TokenRequest(BaseModel):
    telegram_id: int
    secret: str  # bot dan kelgan maxfiy kalit

@app.post("/api/v1/auth/token")
async def create_token(
    body: TokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """Bot foydalanuvchi uchun JWT token oladi.
    Bot /login_app komandasi shu endpointni chaqiradi."""
    bot_secret = os.getenv("BOT_API_SECRET", "change-me")
    if body.secret != bot_secret:
        raise HTTPException(403, "Invalid secret")

    res = await db.execute(
        select(User).where(User.telegram_id == body.telegram_id)
    )
    user = res.scalar_one_or_none()
    if not user:
        raise HTTPException(404, "User not found — first /start in bot")

    token = create_app_token(user.id, user.telegram_id)
    return {"token": token, "user_id": user.id}


# ── Helpers ───────────────────────────────────────────────
def _user_to_dict(u: User) -> dict:
    return {
        "id": u.id,
        "telegram_id": u.telegram_id,
        "full_name": u.full_name,
        "display_name": u.display_name,
        "username": u.username,
        "photo_url": u.photo_url,
        "custom_photo_url": u.custom_photo_url,
        "streak": u.streak or 0,
        "total_score": u.total_score or 0,
        "xp": u.xp or 0,
        "level": u.level or 1,
        "longest_streak": u.longest_streak or 0,
        "streak_freezes": u.streak_freezes or 0,
        "discipline_score": u.discipline_score or 50,
        "weekly_xp": u.weekly_xp or 0,
        "perfect_days": u.perfect_days or 0,
        "is_premium": u.is_premium or False,
        "premium_until": str(u.premium_until) if u.premium_until else None,
        "onboarded": u.onboarded or False,
        "rank_title": u.rank_title,
        "avatar_emoji": u.avatar_emoji or "🌱",
        "referral_count": u.referral_count or 0,
        "is_active": u.is_active if u.is_active is not None else True,
        "notifications_enabled": u.notifications_enabled if u.notifications_enabled is not None else True,
        "created_at": str(u.created_at) if u.created_at else None,
    }


def _plan_to_dict(p: Plan) -> dict:
    return {
        "id": p.id,
        "user_id": p.user_id,
        "title": p.title,
        "description": p.description,
        "scheduled_time": p.scheduled_time,
        "plan_date": str(p.plan_date),
        "status": p.status or "pending",
        "score_value": p.score_value or 5,
        "created_by_user_id": p.created_by_user_id,
    }


def _habit_to_dict(h: Habit) -> dict:
    return {
        "id": h.id,
        "user_id": h.user_id,
        "title": h.title,
        "description": h.description,
        "icon": h.icon or "✅",
        "reminder_time": h.reminder_time,
        "frequency": h.frequency or "daily",
        "weekdays": h.weekdays,
        "duration_type": h.duration_type or "permanent",
        "target_days": h.target_days,
        "start_date": str(h.start_date) if h.start_date else None,
        "sort_order": h.sort_order or 0,
        "archived": h.archived or False,
    }


def _goal_to_dict(g: Goal) -> dict:
    return {
        "id": g.id,
        "user_id": g.user_id,
        "title": g.title,
        "description": g.description,
        "goal_type": g.goal_type or "yearly",
        "period": g.period,
        "completed": g.completed or False,
    }


def _smart_message(user: User) -> str:
    """Foydalanuvchi holatiga qarab motivatsion xabar."""
    streak = user.streak or 0
    disc = user.discipline_score or 50

    if streak == 0:
        return "Bugun birinchi qadamni qo'ying! Har bir sayohat bitta qadam bilan boshlanadi 🌱"
    if streak >= 30:
        return f"Ajoyib! {streak} kunlik streak — siz haqiqiy intizom namunasisiz! 💎🔥"
    if streak >= 7:
        return f"{streak} kun ketma-ket — zo'r natija! Davom eting! 🔥"
    if disc >= 70:
        return "Intizom darajangiz yuqori — shu ruhda davom eting! ⚡"
    if disc < 40:
        return "Kichik qadamlar katta natija beradi. Bugun bitta ish bajaring! 💪"
    return f"Streak: {streak} kun. Bugun ham davom eting! 🎯"
