from fastapi import APIRouter, Depends, HTTPException, status
from .. import schemas, database
from ..repository import users as users_repository
from ..utils import UUIDutils
from sqlalchemy.orm import Session

router = APIRouter(
    prefix='/user',
    tags=['Users']
)

@router.post('/', status_code=status.HTTP_201_CREATED, response_model=schemas.ShowUser)
def create_user(request:schemas.User, db: Session = Depends(database.get_db)):
    db_user = users_repository.create(db, request)
    return db_user

@router.get('/{id}', status_code=status.HTTP_200_OK, response_model=schemas.ShowUser)
def get_user(id:str, db: Session = Depends(database.get_db)):
    if not UUIDutils.isUUID(id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f'user with the id {id} is not found')
    user =  users_repository.get_by_id(db,id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f'user with the id {id} is not found')
    return user