from fastapi import Depends, FastAPI
from . import schemas, models
from .database import SessionLocal, engine
from sqlalchemy.orm import Session

app = FastAPI()

models.Base.metadata.create_all(engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.post('/pokemon')
def create(pokemon: schemas.Pokemon, db: Session = Depends(get_db)):
    pokemon_data = pokemon.dict()
    stats_data = pokemon_data.pop('stats', None)
    db_pokemon = models.Pokemon(**pokemon_data)
    db.add(db_pokemon)
    db.commit()
    db.refresh(db_pokemon)
    stats_data['pokemon_id'] = db_pokemon.id
    db_stats = models.Stats(**stats_data)
    db.add(db_stats)
    db.commit()
    db.refresh(db_stats)
    return db_pokemon

@app.get('/pokemon/{id}')
def get(id:int, db: Session = Depends(get_db)):
    pokemon = db.query(models.Pokemon).filter(models.Pokemon.id == id).first() 
    pokemon_stats = db.query(models.Stats).filter(models.Stats.pokemon_id == pokemon.id).first()
    pokemon.stats = [pokemon_stats]
    return pokemon