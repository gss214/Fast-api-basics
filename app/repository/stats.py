from sqlalchemy.orm import Session
from .. import models, schemas

def create(db: Session, stats: schemas.Stats):
    db_stats = models.Stats(**stats)
    db.add(db_stats)
    db.commit()
    db.refresh(db_stats)
    return db_stats

def get_by_pokemon_id(db: Session, id:str):
    return db.query(models.Stats).filter(models.Stats.pokemon_id == id).first()
    
def delete_by_pokemon_id(db:Session, id:str):
    stats = get_by_pokemon_id(db, id)
    if not stats:
        return False
    db.delete(stats)
    db.commit()
    return True