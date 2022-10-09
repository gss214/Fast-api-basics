from fastapi import Depends, FastAPI, status, HTTPException
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

@app.post('/pokemon', status_code=status.HTTP_201_CREATED)
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
    return {'status':'ok', 'data': pokemon}

@app.delete('/pokemon/{id}', status_code=status.HTTP_204_NO_CONTENT)
def delete(id:int, db: Session = Depends(get_db)):
    pokemon = db.query(models.Pokemon).filter(models.Pokemon.id == id)
    if not pokemon.first():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f'pokemon with the id {id} is not found')
    stats = db.query(models.Stats).filter(models.Stats.pokemon_id == id)
    pokemon.delete(synchronize_session=False)
    stats.delete(synchronize_session=False)
    db.commit()
    return {'ok':True}

@app.get('/pokemon/{id}', status_code=status.HTTP_200_OK)
def get(id:int, db: Session = Depends(get_db)):
    pokemon = db.query(models.Pokemon).filter(models.Pokemon.id == id).first() 
    if not pokemon:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f'pokemon with the id {id} is not found')
    pokemon_stats = db.query(models.Stats).filter(models.Stats.id == pokemon.id).first()
    pokemon.stats = [pokemon_stats]
    return pokemon