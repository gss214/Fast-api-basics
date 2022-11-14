from fastapi import APIRouter, Depends, HTTPException, status
from .. import schemas, database, oauth2
from ..utils import UUIDutils
from ..repository import pokemon as pokemon_repository
from ..repository import stats as stats_repository
from sqlalchemy.orm import Session

router = APIRouter(
    prefix='/pokemon',
    tags=['Pokemons']
)

@router.post('/', status_code=status.HTTP_201_CREATED, response_model=schemas.ShowPokemon)
def create_pokemon(pokemon: schemas.Pokemon, db: Session = Depends(database.get_db), get_current_user: schemas.User = Depends(oauth2.get_current_user)):
    db_pokemon = pokemon_repository.create(db, pokemon)
    stats_data = pokemon.dict().pop('stats', None)
    stats_data['pokemon_id'] = db_pokemon.id
    stats_repository.create(db, stats_data)
    pokemon = pokemon.dict()
    pokemon['id'] = db_pokemon.id
    return pokemon

@router.delete('/{id}', status_code=status.HTTP_204_NO_CONTENT)
def delete_pokemon(id:str, db: Session = Depends(database.get_db), get_current_user: schemas.User = Depends(oauth2.get_current_user)):
    if not UUIDutils.isUUID(id) or not pokemon_repository.delete_by_id(db,id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f'pokemon with the id {id} is not found')
    if not stats_repository.delete_by_pokemon_id(db, id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f'pokemon_stats with the pokemon_id {id} is not found')
    return {'ok':True}

@router.get('/{id}', status_code=status.HTTP_200_OK)
def get_pokemon(id:str, db: Session = Depends(database.get_db)):
    if not UUIDutils.isUUID(id): 
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f'pokemon with the id {id} is not found')
    pokemon = pokemon_repository.get_by_id(db, id)
    if not pokemon:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f'pokemon with the id {id} is not found')
    pokemon_stats = stats_repository.get_by_pokemon_id(db, str(pokemon.id))
    if not pokemon_stats:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f'pokemon_stats with the id {id} is not found')
    pokemon.stats = [pokemon_stats]
    return pokemon
