"""
Configuration package - Database setup and environment variables
"""
from .database import DatabaseManager, get_db_session

__all__ = ['DatabaseManager', 'get_db_session']
