from sqlalchemy import Column, Float, ForeignKey, Integer, String
from .database import Base
from sqlalchemy.orm import relationship

class Stats(Base):
    __tablename__ = 'stats'

    id = Column(Integer,primary_key=True,index=True)
    pokemon_id = Column(Integer,ForeignKey('pokemon.id'))
    pokemon = relationship('Pokemon', back_populates='stats')
    attack = Column(Integer) 
    defense = Column(Integer)
    hp = Column(Integer) 
    special_attack = Column(Integer)
    special_defense = Column(Integer) 
    speed = Column(Integer)

class Pokemon(Base):
    __tablename__ = 'pokemon'

    id = Column(Integer,primary_key=True,index=True)
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
