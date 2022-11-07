from fastapi import APIRouter, Depends, HTTPException, status
from .. import schemas, database
from ..repository import users as users_repository
from sqlalchemy.orm import Session

router = APIRouter(
    prefix='/user',
    tags=['Users']
)

@router.post('/', status_code=status.HTTP_201_CREATED, response_model=schemas.ShowUser)
def create_user(request:schemas.User, db: Session = Depends(database.get_db)):
    return users_repository.create(db, request)

@router.get('/{id}', status_code=status.HTTP_200_OK, response_model=schemas.ShowUser)
def get_user(id:int, db: Session = Depends(database.get_db)):
    user =  users_repository.get_by_id(db,id)
    if not user.first():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f'user with the id {id} is not found')
    return user.first()