import databases
import sqlalchemy
from sqlalchemy.ext.declarative import declarative_base
from .config import settings

# Database connection
database = databases.Database(settings.DATABASE_URL)
metadata = sqlalchemy.MetaData()

# Tables
businesses = sqlalchemy.Table(
    "businesses",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.String, primary_key=True),
    sqlalchemy.Column("name", sqlalchemy.String(255), nullable=False),
    sqlalchemy.Column("phone_number", sqlalchemy.String(20)),
    sqlalchemy.Column("welcome_message", sqlalchemy.Text),
    sqlalchemy.Column("voice_config", sqlalchemy.JSON),
    sqlalchemy.Column("rasa_config", sqlalchemy.JSON),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, server_default=sqlalchemy.func.now()),
    sqlalchemy.Column("updated_at", sqlalchemy.DateTime, server_default=sqlalchemy.func.now()),
    sqlalchemy.Column("is_active", sqlalchemy.Boolean, default=True),
)

call_sessions = sqlalchemy.Table(
    "call_sessions",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.String, primary_key=True),
    sqlalchemy.Column("business_id", sqlalchemy.String, sqlalchemy.ForeignKey("businesses.id")),
    sqlalchemy.Column("caller_id", sqlalchemy.String(20)),
    sqlalchemy.Column("start_time", sqlalchemy.DateTime),
    sqlalchemy.Column("end_time", sqlalchemy.DateTime),
    sqlalchemy.Column("status", sqlalchemy.String(20)),
    sqlalchemy.Column("conversation_history", sqlalchemy.JSON),
    sqlalchemy.Column("summary", sqlalchemy.Text),
    sqlalchemy.Column("metadata", sqlalchemy.JSON),
)

receptionists = sqlalchemy.Table(
    "receptionists",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.String, primary_key=True),
    sqlalchemy.Column("business_id", sqlalchemy.String, sqlalchemy.ForeignKey("businesses.id")),
    sqlalchemy.Column("name", sqlalchemy.String(255), nullable=False),
    sqlalchemy.Column("personality", sqlalchemy.String(50), default="professional"),
    sqlalchemy.Column("voice_settings", sqlalchemy.JSON),
    sqlalchemy.Column("knowledge_base", sqlalchemy.JSON),
    sqlalchemy.Column("capabilities", sqlalchemy.JSON),
    sqlalchemy.Column("is_active", sqlalchemy.Boolean, default=True),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, server_default=sqlalchemy.func.now()),
    sqlalchemy.Column("updated_at", sqlalchemy.DateTime, server_default=sqlalchemy.func.now()),
)

# Database engine
engine = sqlalchemy.create_engine(settings.DATABASE_URL)

def get_db():
    """Get database connection"""
    return database

async def connect_db():
    """Connect to database"""
    await database.connect()

async def disconnect_db():
    """Disconnect from database"""
    await database.disconnect()

def create_tables():
    """Create all tables"""
    metadata.create_all(engine)
