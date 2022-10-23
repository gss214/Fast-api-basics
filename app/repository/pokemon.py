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

def get_by_id(db: Session, id:int):
    return db.query(models.Pokemon).filter(models.Pokemon.id == id) 
    
def delete_by_id(db: Session, id:int):
    pokemon = get_by_id(db, id)
    if not pokemon.first():
        return False
    pokemon.delete(synchronize_session=False)
    db.commit()
    return True