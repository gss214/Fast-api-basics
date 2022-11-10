from sqlalchemy.orm import Session
from .. import models, schemas
from ..hashing import Hash

def create(db: Session, user: schemas.User):
    db_user = models.User(name=user.name,email=user.email,password=Hash.bcrypt(user.password))
    db.add(db_user)
    db.commit()
    db.refresh(db_user)    
    return db_user

def get_by_id(db: Session, id:str):
    return db.query(models.User).filter(models.User.id == id).first()
 