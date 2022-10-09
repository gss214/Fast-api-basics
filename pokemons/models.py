from sqlalchemy import Column, Integer, ForeignKey, String
from .database import Base
from sqlalchemy.orm import relationship

class Stats(Base):
    __tablename__ = 'stats'

    id = Column(Integer,primary_key=True,index=True)
    pokemon_id = Column(Integer,ForeignKey('pokemon.id'))
    pokemon = relationship("Pokemon", back_populates='stats')
    hp = Column(Integer) 
    attack = Column(Integer) 
    defense = Column(Integer)
    special_attack = Column(Integer)
    special_defense = Column(Integer) 
    speed = Column(Integer)

class Pokemon(Base):
    __tablename__ = 'pokemon'

    id = Column(Integer,primary_key=True,index=True)
    id_pokedex = Column(Integer)
    name = Column(String)
    type = Column(String)
    stats = relationship("Stats", back_populates='pokemon')
    weaknesses = Column(String)