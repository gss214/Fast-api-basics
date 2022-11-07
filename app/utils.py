import uuid

class UUIDutils():
    def isUUID(id):
        try:
            uuid.UUID(str(id))
            return True
        except ValueError:
            return False

    def genUUID4():
        return uuid.uuid4