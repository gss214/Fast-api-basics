from sqlalchemy.orm import Session
from .. import models, schemas

def create(db: Session, pokemon: schemas.Pokemon):
    pokemon_data = pokemon.dict()
    pokemon_data.pop('stats',None)
    db_pokemon = models.Pokemon(**pokemon_data)
    db.add(db_pokemon)
    db.commit()
    db.refresh(db_pokemon)
    return db_pokemon

def get_by_id(db: Session, id:str):
    return db.query(models.Pokemon).filter(models.Pokemon.id == id).first()
    
def delete_by_id(db: Session, id:str):
    pokemon = get_by_id(db, id)
    if not pokemon:
        return False
    db.delete(pokemon)
    return True
