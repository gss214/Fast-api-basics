from pydantic import BaseModel
from uuid import UUID

class Stats(BaseModel):
    attack: int 
    defense: int
    hp: int 
    special_attack: int
    special_defense: int 
    speed: int

    class Config:
        orm_mode = True

class Image(BaseModel):
    url: str

class Pokemon(BaseModel):
    abillities: str
    category: str
    gender: str
    height: float
    id_pokedex: int
    name: str
    stats: Stats
    type: str
    weaknesses: str
    weight: float

    class Config:
        orm_mode = True

class ShowPokemon(Pokemon):
    id: UUID

class User(BaseModel):
    name: str
    email: str
    password: str
    
class ShowUser(BaseModel):
    id: UUID
    name: str
    email: str

    class Config:
        orm_mode = True 
