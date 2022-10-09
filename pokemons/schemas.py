from pydantic import BaseModel
from typing import Optional

class Stats(BaseModel):
    hp: int 
    attack: int 
    defense: int
    special_attack: int
    special_defense: int 
    speed: int

    class Config:
        orm_mode = True

class Image(BaseModel):
    url: str

class Pokemon(BaseModel):
    id_pokedex: int
    name: str
    type: str
    stats: Stats
    weaknesses: str

    class Config:
        orm_mode = True
