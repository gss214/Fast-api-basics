from .database import Base
from .utils import UUIDutils
from sqlalchemy import Column, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship
from sqlalchemy_utils import UUIDType

class Stats(Base):
    __tablename__ = 'stats'

    id = Column(UUIDType(binary=False), primary_key=True, default=UUIDutils.genUUID4())
    pokemon_id = Column(UUIDType(binary=False), ForeignKey('pokemon.id'))
    pokemon = relationship('Pokemon', back_populates='stats')
    attack = Column(Integer) 
    defense = Column(Integer)
    hp = Column(Integer) 
    special_attack = Column(Integer)
    special_defense = Column(Integer) 
    speed = Column(Integer)

class Pokemon(Base):
    __tablename__ = 'pokemon'

    id = Column(UUIDType(binary=False), primary_key=True, default=UUIDutils.genUUID4())
    id_pokedex = Column(Integer)
    abillities = Column(String)
    category = Column(String)
    gender = Column(String)
    height = Column(Float)
    name = Column(String)
    type = Column(String)
    weaknesses = Column(String)
    weight = Column(Float)
    stats = relationship('Stats', back_populates='pokemon')

class User(Base):
    __tablename__ = 'user'

    id = Column(UUIDType(binary=False), primary_key=True, default=UUIDutils.genUUID4())
    name = Column(String)
    email = Column(String)
    password = Column(String)