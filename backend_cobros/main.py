from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, Boolean, Enum, Date
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.sql import func
from pydantic import BaseModel
from datetime import datetime, date, timedelta
from passlib.context import CryptContext
import enum
import os
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

# 1. Configuración de la Base de Datos (PostgreSQL Neon)
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://neondb_owner:npg_wEkTUn6NYb7B@ep-bold-breeze-amsykmxb-pooler.c-5.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
)

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False} if "sqlite" in DATABASE_URL else {},
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Configuración de seguridad
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Enums
class RolUsuario(str, enum.Enum):
    ADMINISTRADOR = "administrador"
    TRABAJADOR = "trabajador"

class FrecuenciaCuota(str, enum.Enum):
    SEMANAL = "semanal"
    QUINCENAL = "quincenal"
    MENSUAL = "mensual"

# ============= MODELOS DE BASE DE DATOS =============

class Usuario(Base):
    __tablename__ = "usuarios"
    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String, index=True)
    email = Column(String, unique=True, index=True)
    password_hash = Column(String)
    rol = Column(Enum(RolUsuario), default=RolUsuario.TRABAJADOR)
    activo = Column(Boolean, default=True)
    fecha_creacion = Column(DateTime, default=datetime.utcnow)

class Cliente(Base):
    __tablename__ = "clientes"
    id = Column(Integer, primary_key=True, index=True)
    nombres = Column(String)
    cedula = Column(String, unique=True, index=True)
    telefono = Column(String)
    usuario_id = Column(Integer)  # Admin que lo registró
    trabajador_id = Column(Integer, nullable=True)  # (DEPRECADO) Mantener por compatibilidad
    fecha_creacion = Column(DateTime, default=datetime.utcnow)
    activo = Column(Boolean, default=True)
    dia_cobro = Column(String, default="lunes")  # Día de cobro: lunes, martes, ...


class TrabajadorDia(Base):
    __tablename__ = "trabajadores_dia"
    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, index=True)
    dia = Column(String)  # lunes, martes, miercoles, etc.



class Prestamo(Base):
    __tablename__ = "prestamos"
    id = Column(Integer, primary_key=True, index=True)
    cliente_id = Column(Integer, index=True)
    usuario_id = Column(Integer)  # Trabajador que registró
    monto_prestado = Column(Float)
    total_deuda = Column(Float)  # Con interés 20%
    deuda_restante = Column(Float)
    interes_porcentaje = Column(Float, default=20.0)
    valor_cartulina = Column(Float)
    fecha_prestamo = Column(DateTime, default=datetime.utcnow)
    pagado = Column(Boolean, default=False)
    fecha_finalizacion = Column(DateTime, nullable=True)

class Cuota(Base):
    __tablename__ = "cuotas"
    id = Column(Integer, primary_key=True, index=True)
    prestamo_id = Column(Integer, index=True)
    numero_cuota = Column(Integer)
    valor_cuota = Column(Float)
    fecha_vencimiento = Column(Date)
    pagada = Column(Boolean, default=False)
    valor_pagado = Column(Float, default=0.0)
    valor_pendiente = Column(Float)
    atrasada = Column(Boolean, default=False)
    fecha_creacion = Column(DateTime, default=datetime.utcnow)

class PagoCuota(Base):
    __tablename__ = "pagos_cuota"
    id = Column(Integer, primary_key=True, index=True)
    cuota_id = Column(Integer, index=True)
    prestamo_id = Column(Integer, index=True)
    cantidad_pagada = Column(Float)
    fecha_pago = Column(DateTime, default=datetime.utcnow)
    usuario_id = Column(Integer)  # Quien registró el pago

class IngresoDia(Base):
    __tablename__ = "ingresos_dia"
    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, index=True)
    fecha = Column(Date, default=date.today)
    ingreso_cuotas = Column(Float, default=0.0)
    ingreso_cartulinas = Column(Float, default=0.0)
    total_ingresos = Column(Float, default=0.0)

class GastoDia(Base):
    __tablename__ = "gastos_dia"
    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, index=True)
    fecha = Column(Date, default=date.today)
    concepto = Column(String)  # "almuerzo", "varios", etc
    valor = Column(Float)
    fecha_registro = Column(DateTime, default=datetime.utcnow)

class CierreDia(Base):
    __tablename__ = "cierres_dia"
    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, index=True)
    fecha_cierre = Column(Date, index=True)
    total_cuotas_pagadas = Column(Float)
    total_cartulinas = Column(Float)
    total_gastos = Column(Float)
    saldo_neto = Column(Float)
    fecha_creacion = Column(DateTime, default=datetime.utcnow)
    cerrado = Column(Boolean, default=True)

# ============= ESQUEMAS PYDANTIC =============

class UsuarioRegistro(BaseModel):
    nombres: str
    email: str
    password: str
    rol: RolUsuario = RolUsuario.TRABAJADOR

class UsuarioLogin(BaseModel):
    email: str
    password: str

class ClienteRegistro(BaseModel):
    nombres: str
    cedula: str
    telefono: str
    dia_cobro: str = "lunes"

class ClientePrestamoRegistro(BaseModel):
    nombres: str
    cedula: str
    telefono: str
    dia_cobro: str = "lunes"
    monto_prestado: float
    interes_porcentaje: float = 20.0
    numero_cuotas: int
    frecuencia: FrecuenciaCuota

class ClienteResponse(BaseModel):
    id: int
    nombres: str
    cedula: str
    telefono: str
    fecha_creacion: datetime

class PrestamoRegistro(BaseModel):
    cliente_id: int
    monto_prestado: float
    interes_porcentaje: float = 20.0
    numero_cuotas: int
    frecuencia: FrecuenciaCuota

class PagoCuotaRegistro(BaseModel):
    cuota_id: int
    cantidad_pagada: float

class GestionCuotaVencidaRequest(BaseModel):
    cuota_id: int
    accion: str
    nuevo_porcentaje: Optional[float] = None

class GastoDiaRegistro(BaseModel):
    concepto: str
    valor: float

# Crear las tablas (solo create, sin drop)
Base.metadata.create_all(bind=engine)

# ============= INICIALIZAR FastAPI =============

app = FastAPI(
    title="Sistema de Cobros",
    version="1.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Función para obtener la sesión
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ============= FUNCIONES AUXILIARES =============

def hash_password(password: str) -> str:
    print(f"Contraseña recibida para hash: '{password}' (len={len(password)})")
    if len(password) > 72:
        raise ValueError("La contraseña no puede tener más de 72 caracteres.")
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def calcular_fecha_vencimiento(fecha_inicio: date, numero_cuota: int, frecuencia: FrecuenciaCuota) -> date:
    if frecuencia == FrecuenciaCuota.SEMANAL:
        return fecha_inicio + timedelta(weeks=numero_cuota)
    elif frecuencia == FrecuenciaCuota.QUINCENAL:
        return fecha_inicio + timedelta(days=15 * numero_cuota)
    else:  # MENSUAL
        return fecha_inicio + timedelta(days=30 * numero_cuota)


def _coerce_bool(value):
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "1", "si", "sí", "yes", "y"}:
            return True
        if lowered in {"false", "0", "no", "n"}:
            return False
    return bool(value)

# ============= ENDPOINTS: AUTENTICACIÓN =============

@app.post("/api/auth/registro")
def registro_usuario(usuario: UsuarioRegistro, db: Session = Depends(get_db)):
    # Solo permite registrar administradores (o el primer usuario será admin)
    usuarios_existentes = db.query(Usuario).count()
    if usuarios_existentes > 0 and usuario.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo se pueden registrar administradores. Contacte al admin para registrarse como trabajador")
    
    # Verificar si el email ya existe
    db_usuario = db.query(Usuario).filter(Usuario.email == usuario.email).first()
    if db_usuario:
        raise HTTPException(status_code=400, detail="El email ya está registrado")
    
    # Si es el primer usuario, será administrador
    rol = RolUsuario.ADMINISTRADOR if usuarios_existentes == 0 else usuario.rol
    
    nuevo_usuario = Usuario(
        nombre=usuario.nombres,
        email=usuario.email,
        password_hash=hash_password(usuario.password),
        rol=rol
    )
    db.add(nuevo_usuario)
    db.commit()
    db.refresh(nuevo_usuario)
    
    return {
        "status": "success",
        "usuario_id": nuevo_usuario.id,
        "nombre": nuevo_usuario.nombre,
        "rol": nuevo_usuario.rol,
        "mensaje": f"Usuario registrado como {rol}"
    }

@app.post("/api/auth/login")
def login(credenciales: UsuarioLogin, db: Session = Depends(get_db)):
    usuario = db.query(Usuario).filter(Usuario.email == credenciales.email).first()
    
    if not usuario or not verify_password(credenciales.password, usuario.password_hash):
        raise HTTPException(status_code=401, detail="Email o contraseña incorrectos")
    
    return {
        "status": "success",
        "usuario_id": usuario.id,
        "nombre": usuario.nombre,
        "email": usuario.email,
        "rol": usuario.rol
    }

# ============= ENDPOINTS: ADMINISTRACIÓN DE TRABAJADORES =============

@app.post("/api/admin/registrar-trabajador")
def registrar_trabajador(usuario: UsuarioRegistro, admin_id: int, db: Session = Depends(get_db)):
    # Verificar que el usuario que solicita es administrador
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden registrar trabajadores")
    
    # Verificar si el email ya existe
    db_usuario = db.query(Usuario).filter(Usuario.email == usuario.email).first()
    if db_usuario:
        raise HTTPException(status_code=400, detail="El email ya está registrado")
    
    # Crear nuevo trabajador (siempre como TRABAJADOR)
    nuevo_trabajador = Usuario(
        nombre=usuario.nombres,
        email=usuario.email,
        password_hash=hash_password(usuario.password),
        rol=RolUsuario.TRABAJADOR
    )
    db.add(nuevo_trabajador)
    db.commit()
    db.refresh(nuevo_trabajador)
    
    return {
        "status": "success",
        "usuario_id": nuevo_trabajador.id,
        "nombre": nuevo_trabajador.nombre,
        "rol": nuevo_trabajador.rol,
        "mensaje": f"Trabajador {usuario.nombres} registrado exitosamente"
    }

@app.get("/api/admin/listar-trabajadores")
def listar_trabajadores(admin_id: int, db: Session = Depends(get_db)):
    # Verificar que el usuario que solicita es administrador
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden acceder a esto")
    
    # Obtener todos los trabajadores
    trabajadores = db.query(Usuario).filter(Usuario.rol == RolUsuario.TRABAJADOR).all()
    
    resultado = []
    for t in trabajadores:
        # Contar clientes cuyo `dia_cobro` está entre los días asignados a este trabajador
        dias_asignados = [d[0] for d in db.query(TrabajadorDia.dia).filter(TrabajadorDia.usuario_id == t.id).all()]
        if dias_asignados:
            clientes_asignados = db.query(Cliente).filter(Cliente.dia_cobro.in_(dias_asignados), Cliente.activo == True).count()
        else:
            clientes_asignados = 0
        resultado.append({
            "id": t.id,
            "nombre": t.nombre,
            "email": t.email,
            "activo": t.activo,
            "fecha_creacion": t.fecha_creacion,
            "clientes_asignados": clientes_asignados,
            "dias_asignados": dias_asignados
        })
    
    return resultado


@app.post("/api/admin/editar-trabajador")
async def editar_trabajador(request: Request, admin_id: int, trabajador_id: int, nombres: str = None, email: str = None, activo: bool = None, password: str = None, db: Session = Depends(get_db)):
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden editar trabajadores")

    trabajador = db.query(Usuario).filter(Usuario.id == trabajador_id, Usuario.rol == RolUsuario.TRABAJADOR).first()
    if not trabajador:
        raise HTTPException(status_code=404, detail="Trabajador no encontrado")

    body = {}
    try:
        body = await request.json()
    except Exception:
        body = {}

    nombres = request.query_params.get("nombres") if request.query_params.get("nombres") is not None else (body.get("nombres") or nombres)
    email = request.query_params.get("email") if request.query_params.get("email") is not None else (body.get("email") or email)
    activo_raw = request.query_params.get("activo") if request.query_params.get("activo") is not None else body.get("activo")
    password = request.query_params.get("password") if request.query_params.get("password") is not None else (body.get("password") or password)
    activo = _coerce_bool(activo_raw) if activo_raw is not None else activo

    if nombres:
        trabajador.nombre = nombres
    if email and email != trabajador.email:
        # Verificar conflicto de email
        existe = db.query(Usuario).filter(Usuario.email == email).first()
        if existe:
            raise HTTPException(status_code=400, detail="Email ya en uso")
        trabajador.email = email
    if activo is not None:
        trabajador.activo = activo
    if password:
        trabajador.password_hash = hash_password(password)

    db.commit()
    db.refresh(trabajador)

    return {"status": "success", "trabajador_id": trabajador.id, "mensaje": "Trabajador actualizado"}


@app.post("/api/admin/eliminar-trabajador")
def eliminar_trabajador(admin_id: int, trabajador_id: int, db: Session = Depends(get_db)):
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden eliminar trabajadores")

    trabajador = db.query(Usuario).filter(Usuario.id == trabajador_id, Usuario.rol == RolUsuario.TRABAJADOR).first()
    if not trabajador:
        raise HTTPException(status_code=404, detail="Trabajador no encontrado")

    # Soft delete: desactivar
    trabajador.activo = False
    db.commit()

    return {"status": "success", "trabajador_id": trabajador.id, "mensaje": "Trabajador desactivado"}


@app.post("/api/admin/asignar-trabajador-dia")
def asignar_trabajador_dia(admin_id: int, trabajador_id: int, dia: str, db: Session = Depends(get_db)):
    # Verificar que el usuario que solicita es administrador
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden asignar días a trabajadores")

    trabajador = db.query(Usuario).filter(Usuario.id == trabajador_id, Usuario.rol == RolUsuario.TRABAJADOR).first()
    if not trabajador:
        raise HTTPException(status_code=404, detail="Trabajador no encontrado")

    # Evitar duplicados
    existente = db.query(TrabajadorDia).filter(TrabajadorDia.usuario_id == trabajador_id, TrabajadorDia.dia == dia).first()
    if existente:
        raise HTTPException(status_code=400, detail="El trabajador ya tiene asignado ese día")

    asignacion = TrabajadorDia(usuario_id=trabajador_id, dia=dia)
    db.add(asignacion)
    db.commit()

    return {"status": "success", "mensaje": f"Trabajador {trabajador.nombre} asignado al día {dia}"}


@app.post("/api/admin/desasignar-trabajador-dia")
def desasignar_trabajador_dia(admin_id: int, trabajador_id: int, dia: str, db: Session = Depends(get_db)):
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden desasignar días")

    asignacion = db.query(TrabajadorDia).filter(TrabajadorDia.usuario_id == trabajador_id, TrabajadorDia.dia == dia).first()
    if not asignacion:
        raise HTTPException(status_code=404, detail="Asignación no encontrada")

    db.delete(asignacion)
    db.commit()

    return {"status": "success", "mensaje": f"Desasignado día {dia} para trabajador {trabajador_id}"}


@app.get("/api/admin/listar-asignaciones")
def listar_asignaciones(admin_id: int, db: Session = Depends(get_db)):
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden ver las asignaciones")

    asignaciones = db.query(TrabajadorDia).all()
    resultado = []
    for a in asignaciones:
        trabajador = db.query(Usuario).filter(Usuario.id == a.usuario_id).first()
        resultado.append({
            "id": a.id,
            "trabajador_id": a.usuario_id,
            "trabajador_nombre": trabajador.nombre if trabajador else None,
            "dia": a.dia
        })

    return resultado


@app.get("/api/admin/listar-clientes")
def listar_clientes_admin(admin_id: int, db: Session = Depends(get_db)):
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden ver clientes")

    clientes = db.query(Cliente).all()
    return [
        {
            "id": c.id,
            "nombres": c.nombres,
            "cedula": c.cedula,
            "telefono": c.telefono,
            "dia_cobro": c.dia_cobro,
            "activo": c.activo,
            "fecha_creacion": c.fecha_creacion
        }
        for c in clientes
    ]


@app.get("/api/admin/alertas-cuotas-vencidas")
def alertas_cuotas_vencidas(admin_id: int, db: Session = Depends(get_db)):
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden ver alertas")

    hoy = date.today()
    cuotas = db.query(Cuota).filter(Cuota.pagada == False, Cuota.fecha_vencimiento <= hoy).all()
    alertas = []

    for cuota in cuotas:
        prestamo = db.query(Prestamo).filter(Prestamo.id == cuota.prestamo_id).first()
        if not prestamo:
            continue

        cliente = db.query(Cliente).filter(Cliente.id == prestamo.cliente_id).first()
        if not cliente:
            continue

        cuota.atrasada = True
        dias_atrasados = (hoy - cuota.fecha_vencimiento).days if cuota.fecha_vencimiento else 0
        alertas.append({
            "id": cuota.id,
            "cuota_id": cuota.id,
            "prestamo_id": prestamo.id,
            "cliente_id": cliente.id,
            "cliente_nombre": cliente.nombres,
            "cedula": cliente.cedula,
            "numero_cuota": cuota.numero_cuota,
            "valor": cuota.valor_cuota,
            "pendiente": cuota.valor_pendiente,
            "vencimiento": cuota.fecha_vencimiento,
            "dias_atrasados": dias_atrasados,
        })

    db.commit()
    return alertas


@app.post("/api/admin/gestionar-cuota-vencida")
def gestionar_cuota_vencida(request: GestionCuotaVencidaRequest, admin_id: int, db: Session = Depends(get_db)):
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden gestionar cuotas vencidas")

    cuota = db.query(Cuota).filter(Cuota.id == request.cuota_id).first()
    if not cuota:
        raise HTTPException(status_code=404, detail="Cuota no encontrada")

    prestamo = db.query(Prestamo).filter(Prestamo.id == cuota.prestamo_id).first()
    if not prestamo:
        raise HTTPException(status_code=404, detail="Préstamo no encontrado")

    if request.accion == "dejar":
        cuota.atrasada = True
        db.commit()
        return {"status": "success", "mensaje": "Se dejó la cuota tal como está"}

    if request.accion == "agregar_cuota":
        nueva_fecha = (cuota.fecha_vencimiento + timedelta(days=7)) if cuota.fecha_vencimiento else date.today() + timedelta(days=7)
        ultima_cuota = db.query(Cuota).filter(Cuota.prestamo_id == prestamo.id).order_by(Cuota.numero_cuota.desc()).first()
        nueva_numero = (ultima_cuota.numero_cuota if ultima_cuota else 0) + 1
        valor_cuota = cuota.valor_cuota or 0.0
        nueva_cuota = Cuota(
            prestamo_id=prestamo.id,
            numero_cuota=nueva_numero,
            valor_cuota=valor_cuota,
            fecha_vencimiento=nueva_fecha,
            valor_pendiente=valor_cuota,
            pagada=False,
            atrasada=False,
        )
        db.add(nueva_cuota)
        prestamo.total_deuda = (prestamo.total_deuda or 0.0) + valor_cuota
        prestamo.deuda_restante = (prestamo.deuda_restante or 0.0) + valor_cuota
        db.commit()
        return {"status": "success", "mensaje": "Se agregó una cuota extra"}

    if request.accion == "aplicar_interes":
        if request.nuevo_porcentaje is None:
            raise HTTPException(status_code=400, detail="Debe indicar el porcentaje")
        porcentaje_anterior = prestamo.interes_porcentaje or 0.0
        prestamo.interes_porcentaje = request.nuevo_porcentaje
        if prestamo.deuda_restante is not None and prestamo.deuda_restante > 0:
            delta = request.nuevo_porcentaje - porcentaje_anterior
            if delta > 0:
                aumento = prestamo.deuda_restante * (delta / 100)
                prestamo.deuda_restante = prestamo.deuda_restante + aumento
                prestamo.total_deuda = (prestamo.total_deuda or 0.0) + aumento
        cuota.atrasada = True
        db.commit()
        return {"status": "success", "mensaje": f"Se ajustó el interés a {request.nuevo_porcentaje}%"}

    raise HTTPException(status_code=400, detail="Acción no soportada")


@app.post("/api/admin/editar-cliente")
async def editar_cliente_admin(request: Request, admin_id: int, cliente_id: int, nombres: str = None, telefono: str = None, dia_cobro: str = None, activo: bool = None, db: Session = Depends(get_db)):
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden editar clientes")

    cliente = db.query(Cliente).filter(Cliente.id == cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")

    body = {}
    try:
        body = await request.json()
    except Exception:
        body = {}

    nombres = request.query_params.get("nombres") if request.query_params.get("nombres") is not None else (body.get("nombres") or nombres)
    telefono = request.query_params.get("telefono") if request.query_params.get("telefono") is not None else (body.get("telefono") or telefono)
    dia_cobro = request.query_params.get("dia_cobro") if request.query_params.get("dia_cobro") is not None else (body.get("dia_cobro") or dia_cobro)
    activo_raw = request.query_params.get("activo") if request.query_params.get("activo") is not None else body.get("activo")
    activo = _coerce_bool(activo_raw) if activo_raw is not None else activo

    if nombres:
        cliente.nombres = nombres
    if telefono:
        cliente.telefono = telefono
    if dia_cobro:
        cliente.dia_cobro = dia_cobro
    if activo is not None:
        cliente.activo = activo

    db.commit()
    db.refresh(cliente)

    return {"status": "success", "cliente_id": cliente.id, "mensaje": "Cliente actualizado"}


@app.post("/api/admin/eliminar-cliente")
def eliminar_cliente_admin(admin_id: int, cliente_id: int, db: Session = Depends(get_db)):
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden eliminar clientes")

    cliente = db.query(Cliente).filter(Cliente.id == cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")

    # Soft delete: marcar inactivo
    cliente.activo = False
    db.commit()

    return {"status": "success", "cliente_id": cliente.id, "mensaje": "Cliente desactivado"}


@app.post("/api/admin/agregar-interes-mora")
def agregar_interes_mora(admin_id: int, cuota_id: int, monto_interes: float, db: Session = Depends(get_db)):
    """
    Permite al administrador agregar un monto fijo de intereses de mora a una cuota.
    Actualiza la cuota y el préstamo relacionado (total_deuda y deuda_restante).
    """
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden aplicar intereses de mora")

    cuota = db.query(Cuota).filter(Cuota.id == cuota_id).first()
    if not cuota:
        raise HTTPException(status_code=404, detail="Cuota no encontrada")

    prestamo = db.query(Prestamo).filter(Prestamo.id == cuota.prestamo_id).first()
    if not prestamo:
        raise HTTPException(status_code=404, detail="Préstamo relacionado no encontrado")

    # Aplicar intereses: aumentar valor_cuota y valor_pendiente en la cuota
    cuota.valor_cuota = (cuota.valor_cuota or 0.0) + monto_interes
    cuota.valor_pendiente = (cuota.valor_pendiente or 0.0) + monto_interes

    # Actualizar el préstamo: total_deuda y deuda_restante
    prestamo.total_deuda = (prestamo.total_deuda or 0.0) + monto_interes
    prestamo.deuda_restante = (prestamo.deuda_restante or 0.0) + monto_interes

    db.commit()

    return {"status": "success", "cuota_id": cuota.id, "monto_interes": monto_interes, "mensaje": "Interés de mora agregado"}

@app.post("/api/admin/asignar-cliente")
def asignar_cliente(admin_id: int, cliente_id: int, trabajador_id: int, db: Session = Depends(get_db)):
    # Verificar que el usuario que solicita es administrador
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden asignar clientes")
    
    # Verificar que el cliente existe
    cliente = db.query(Cliente).filter(Cliente.id == cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    
    # Verificar que el trabajador existe
    trabajador = db.query(Usuario).filter(
        Usuario.id == trabajador_id,
        Usuario.rol == RolUsuario.TRABAJADOR
    ).first()
    if not trabajador:
        raise HTTPException(status_code=404, detail="Trabajador no encontrado")
    
    # Este endpoint queda obsoleto: la asignación se hace por día.
    raise HTTPException(status_code=400, detail="Asignación directa de cliente a trabajador está obsoleta. Asigne el trabajador a un día con /api/admin/asignar-trabajador-dia")

@app.post("/api/admin/desasignar-cliente")
def desasignar_cliente(admin_id: int, cliente_id: int, db: Session = Depends(get_db)):
    # Verificar que el usuario que solicita es administrador
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden desasignar clientes")
    
    # Verificar que el cliente existe
    cliente = db.query(Cliente).filter(Cliente.id == cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    
    # Desasignar cliente
    cliente.trabajador_id = None
    db.commit()
    
    return {
        "status": "success",
        "mensaje": f"Cliente {cliente.nombres} desasignado"
    }

@app.get("/api/admin/clientes-sin-asignar")
def clientes_sin_asignar(admin_id: int, db: Session = Depends(get_db)):
    # Verificar que el usuario que solicita es administrador
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden acceder a esto")
    
    # Obtener clientes cuyo día no tiene ningún trabajador asignado
    clientes = db.query(Cliente).filter(Cliente.activo == True).all()

    resultado = []
    for c in clientes:
        asignado = db.query(TrabajadorDia).filter(TrabajadorDia.dia == c.dia_cobro).first()
        if not asignado:
            resultado.append({
                "id": c.id,
                "nombres": c.nombres,
                "cedula": c.cedula,
                "telefono": c.telefono,
                "dia_cobro": c.dia_cobro,
                "fecha_creacion": c.fecha_creacion
            })

    return resultado

# ============= ENDPOINTS: CLIENTES =============

@app.post("/api/clientes/registrar")
def registrar_cliente(cliente: ClienteRegistro, admin_id: int, db: Session = Depends(get_db)):
    # Verificar que el usuario que solicita es administrador
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden registrar clientes")
    
    # Verificar si la cédula ya existe
    db_cliente = db.query(Cliente).filter(Cliente.cedula == cliente.cedula).first()
    if db_cliente and db_cliente.activo:
        raise HTTPException(status_code=400, detail="Cliente con esta cédula ya existe")
    
    nuevo_cliente = Cliente(
        nombres=cliente.nombres,
        cedula=cliente.cedula,
        telefono=cliente.telefono,
        usuario_id=admin_id,
        trabajador_id=None,  # Se asignará después
        dia_cobro=cliente.dia_cobro
    )
    db.add(nuevo_cliente)
    db.commit()
    db.refresh(nuevo_cliente)
    
    return {
        "status": "success",
        "cliente_id": nuevo_cliente.id,
        "mensaje": f"Cliente {cliente.nombres} registrado correctamente. Puede registrar el préstamo inmediatamente con /api/clientes/registrar-con-prestamo"
    }

@app.post("/api/clientes/registrar-con-prestamo")
def registrar_cliente_con_prestamo(datos: ClientePrestamoRegistro, admin_id: int = None, db: Session = Depends(get_db)):
    """
    Registra un cliente Y crea un préstamo en una sola transacción.
    Solo para administradores.
    admin_id puede venir en query o en el body.
    """
    # Si admin_id no viene como query, intentar sacarlo del contexto
    if admin_id is None:
        raise HTTPException(status_code=400, detail="admin_id es requerido")
    
    # Verificar que el usuario que solicita es administrador
    admin = db.query(Usuario).filter(Usuario.id == admin_id).first()
    if not admin or admin.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden registrar clientes")
    
    # Verificar si la cédula ya existe
    db_cliente = db.query(Cliente).filter(Cliente.cedula == datos.cedula).first()
    if db_cliente and db_cliente.activo:
        raise HTTPException(status_code=400, detail="Cliente con esta cédula ya existe")
    
    # Crear cliente
    nuevo_cliente = Cliente(
        nombres=datos.nombres,
        cedula=datos.cedula,
        telefono=datos.telefono,
        usuario_id=admin_id,
        trabajador_id=None,
        dia_cobro=datos.dia_cobro
    )
    db.add(nuevo_cliente)
    db.commit()
    db.refresh(nuevo_cliente)
    
    # Crear préstamo
    interes = datos.monto_prestado * (datos.interes_porcentaje / 100)
    total_deuda = datos.monto_prestado + interes
    valor_cartulina = (datos.monto_prestado / 100000) * 5000
    valor_cuota = total_deuda / datos.numero_cuotas
    
    nuevo_prestamo = Prestamo(
        cliente_id=nuevo_cliente.id,
        usuario_id=admin_id,
        monto_prestado=datos.monto_prestado,
        total_deuda=total_deuda,
        deuda_restante=total_deuda,
        interes_porcentaje=datos.interes_porcentaje,
        valor_cartulina=valor_cartulina
    )
    db.add(nuevo_prestamo)
    db.commit()
    db.refresh(nuevo_prestamo)
    
    # Crear cuotas
    for i in range(1, datos.numero_cuotas + 1):
        fecha_vencimiento = calcular_fecha_vencimiento(
            date.today(), i, datos.frecuencia
        )
        cuota = Cuota(
            prestamo_id=nuevo_prestamo.id,
            numero_cuota=i,
            valor_cuota=valor_cuota,
            fecha_vencimiento=fecha_vencimiento,
            valor_pendiente=valor_cuota
        )
        db.add(cuota)
    db.commit()
    
    # Registrar ingreso de cartulina
    ingreso = db.query(IngresoDia).filter(
        IngresoDia.usuario_id == admin_id,
        IngresoDia.fecha == date.today()
    ).first()
    
    if not ingreso:
        ingreso = IngresoDia(usuario_id=admin_id)
        db.add(ingreso)

    if ingreso.ingreso_cartulinas is None:
        ingreso.ingreso_cartulinas = 0.0
    ingreso.ingreso_cartulinas += valor_cartulina
    if ingreso.ingreso_cuotas is None:
        ingreso.ingreso_cuotas = 0.0
    ingreso.total_ingresos = ingreso.ingreso_cuotas + ingreso.ingreso_cartulinas
    db.commit()
    
    return {
        "status": "success",
        "cliente_id": nuevo_cliente.id,
        "prestamo_id": nuevo_prestamo.id,
        "total_deuda": total_deuda,
        "valor_cartulina": valor_cartulina,
        "valor_cuota": valor_cuota,
        "numero_cuotas": datos.numero_cuotas,
        "mensaje": f"Cliente {datos.nombres} registrado con préstamo de ${datos.monto_prestado}"
    }

@app.get("/api/clientes/buscar")
def buscar_cliente(cedula: str = None, nombre: str = None, usuario_id: int = None, db: Session = Depends(get_db)):
    """
    Si usuario_id es trabajador, solo busca entre sus clientes asignados.
    Si es admin, busca entre todos los clientes.
    """
    usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first() if usuario_id else None
    
    query = db.query(Cliente).filter(Cliente.activo == True)
    
    # Si es trabajador, filtrar solo los clientes cuyos dias estén asignados a ese trabajador
    if usuario and usuario.rol == RolUsuario.TRABAJADOR:
        dias_asignados = [d[0] for d in db.query(TrabajadorDia.dia).filter(TrabajadorDia.usuario_id == usuario_id).all()]
        if not dias_asignados:
            raise HTTPException(status_code=403, detail="No tienes días asignados")
        query = query.filter(Cliente.dia_cobro.in_(dias_asignados))
    
    if cedula:
        query = query.filter(Cliente.cedula == cedula)
    elif nombre:
        query = query.filter(Cliente.nombres.contains(nombre))
    else:
        raise HTTPException(status_code=400, detail="Debe proporcionar cédula o nombre")
    
    clientes = query.all()
    if not clientes:
        raise HTTPException(status_code=404, detail="No se encontraron clientes")
    
    return [
        {
            "id": c.id,
            "nombres": c.nombres,
            "cedula": c.cedula,
            "telefono": c.telefono,
            "usuario_id": c.usuario_id,
            "trabajador_id": c.trabajador_id,
            "dia_cobro": c.dia_cobro,
            "fecha_creacion": c.fecha_creacion,
            "activo": c.activo
        }
        for c in clientes
    ]

@app.get("/api/clientes/{cliente_id}")
def obtener_cliente(cliente_id: int, usuario_id: int = None, db: Session = Depends(get_db)):
    """
    Obtiene detalles de un cliente.
    Los trabajadores solo pueden ver sus clientes asignados.
    """
    cliente = db.query(Cliente).filter(Cliente.id == cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    
    # Si se proporciona usuario_id, verificar permisos
    if usuario_id:
        usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first()
        if usuario and usuario.rol == RolUsuario.TRABAJADOR:
                # Trabajador solo puede ver clientes de los días que tenga asignados
                dias_asignados = [d[0] for d in db.query(TrabajadorDia.dia).filter(TrabajadorDia.usuario_id == usuario_id).all()]
                if not dias_asignados or cliente.dia_cobro not in dias_asignados:
                    raise HTTPException(status_code=403, detail="No tienes permiso para ver este cliente")
    
    # Obtener préstamos activos del cliente
    prestamos_activos = db.query(Prestamo).filter(
        Prestamo.cliente_id == cliente_id,
        Prestamo.pagado == False
    ).all()
    
    return {
        "cliente": {
            "id": cliente.id,
            "nombres": cliente.nombres,
            "cedula": cliente.cedula,
            "telefono": cliente.telefono,
            "usuario_id": cliente.usuario_id,
            "trabajador_id": cliente.trabajador_id,
            "dia_cobro": cliente.dia_cobro,
            "fecha_creacion": cliente.fecha_creacion,
            "activo": cliente.activo
        },
        "prestamos_activos": [
            {
                "id": p.id,
                "cliente_id": p.cliente_id,
                "usuario_id": p.usuario_id,
                "monto_prestado": p.monto_prestado,
                "total_deuda": p.total_deuda,
                "deuda_restante": p.deuda_restante,
                "interes_porcentaje": p.interes_porcentaje,
                "valor_cartulina": p.valor_cartulina,
                "fecha_prestamo": p.fecha_prestamo,
                "pagado": p.pagado,
                "fecha_finalizacion": p.fecha_finalizacion
            }
            for p in prestamos_activos
        ]
    }

@app.get("/api/clientes/dia/{dia}")
def clientes_por_dia(dia: str, trabajador_id: int = None, usuario_id: int = None, db: Session = Depends(get_db)):
    """
    Obtiene clientes para un día específico.
    Si es trabajador, solo obtiene sus clientes si tiene asignado ese día.
    Si es admin, devuelve los clientes de ese día sin filtrar por trabajador.
    """
    if usuario_id is not None:
        usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first()
        if not usuario:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        if usuario.rol == RolUsuario.TRABAJADOR:
            asignacion = db.query(TrabajadorDia).filter(TrabajadorDia.usuario_id == usuario_id, TrabajadorDia.dia == dia).first()
            if not asignacion:
                raise HTTPException(status_code=403, detail="No tienes asignado este día")
            clientes = db.query(Cliente).filter(Cliente.dia_cobro == dia, Cliente.activo == True).all()
        elif usuario.rol == RolUsuario.ADMINISTRADOR:
            clientes = db.query(Cliente).filter(Cliente.dia_cobro == dia, Cliente.activo == True).all()
        else:
            raise HTTPException(status_code=403, detail="Usuario no válido")
    elif trabajador_id is not None:
        clientes = db.query(Cliente).filter(Cliente.dia_cobro == dia, Cliente.activo == True).all()
    else:
        raise HTTPException(status_code=400, detail="Debe proporcionar trabajador_id o usuario_id")

    return [
        {
            "id": c.id,
            "nombres": c.nombres,
            "cedula": c.cedula,
            "telefono": c.telefono,
            "dia_cobro": c.dia_cobro,
            "fecha_creacion": c.fecha_creacion,
        }
        for c in clientes
    ]

# ============= ENDPOINTS: PRÉSTAMOS =============

@app.post("/api/prestamos/crear")
def crear_prestamo(prestamo: PrestamoRegistro, usuario_id: int, db: Session = Depends(get_db)):
    # Solo admins pueden crear préstamos normales
    usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if not usuario or usuario.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden crear préstamos")
    
    # Verificar que el cliente existe
    cliente = db.query(Cliente).filter(Cliente.id == prestamo.cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    
    # Cálculos
    interes = prestamo.monto_prestado * (prestamo.interes_porcentaje / 100)
    total_deuda = prestamo.monto_prestado + interes
    valor_cartulina = (prestamo.monto_prestado / 100000) * 5000
    valor_cuota = total_deuda / prestamo.numero_cuotas
    
    # Crear préstamo
    nuevo_prestamo = Prestamo(
        cliente_id=prestamo.cliente_id,
        usuario_id=usuario_id,
        monto_prestado=prestamo.monto_prestado,
        total_deuda=total_deuda,
        deuda_restante=total_deuda,
        interes_porcentaje=prestamo.interes_porcentaje,
        valor_cartulina=valor_cartulina
    )
    db.add(nuevo_prestamo)
    db.commit()
    db.refresh(nuevo_prestamo)
    
    # Crear cuotas
    for i in range(1, prestamo.numero_cuotas + 1):
        fecha_vencimiento = calcular_fecha_vencimiento(
            date.today(), i, prestamo.frecuencia
        )
        cuota = Cuota(
            prestamo_id=nuevo_prestamo.id,
            numero_cuota=i,
            valor_cuota=valor_cuota,
            fecha_vencimiento=fecha_vencimiento,
            valor_pendiente=valor_cuota
        )
        db.add(cuota)
    db.commit()
    
    # Registrar ingreso de cartulina
    ingreso = db.query(IngresoDia).filter(
        IngresoDia.usuario_id == usuario_id,
        IngresoDia.fecha == date.today()
    ).first()
    
    if not ingreso:
        ingreso = IngresoDia(usuario_id=usuario_id)
        db.add(ingreso)

    # Asegurar que ingreso_cartulinas no sea None
    if ingreso.ingreso_cartulinas is None:
        ingreso.ingreso_cartulinas = 0.0
    ingreso.ingreso_cartulinas += valor_cartulina
    # Asegurar que ingreso_cuotas no sea None
    if ingreso.ingreso_cuotas is None:
        ingreso.ingreso_cuotas = 0.0
    ingreso.total_ingresos = ingreso.ingreso_cuotas + ingreso.ingreso_cartulinas
    db.commit()
    
    return {
        "status": "success",
        "prestamo_id": nuevo_prestamo.id,
        "total_deuda": total_deuda,
        "valor_cartulina": valor_cartulina,
        "valor_cuota": valor_cuota,
        "numero_cuotas": prestamo.numero_cuotas,
        "mensaje": f"Préstamo de ${prestamo.monto_prestado} creado para {cliente.nombres}"
    }

@app.post("/api/prestamos/renovar")
def renovar_prestamo(prestamo: PrestamoRegistro, usuario_id: int, db: Session = Depends(get_db)):
    """
    Los trabajadores pueden renovar un préstamo existente.
    Crea un nuevo préstamo marcando el anterior como pagado.
    """
    # Obtener el usuario (trabajador)
    usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    
    # Verificar que el cliente existe y está asignado a este trabajador
    cliente = db.query(Cliente).filter(Cliente.id == prestamo.cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    
    # Verificar que el cliente corresponde a uno de los días asignados al trabajador
    dias_asignados = [d[0] for d in db.query(TrabajadorDia.dia).filter(TrabajadorDia.usuario_id == usuario_id).all()]
    if not dias_asignados or cliente.dia_cobro not in dias_asignados:
        raise HTTPException(status_code=403, detail="No tienes permiso para renovar préstamos de este cliente")
    
    # Obtener el préstamo anterior (el más reciente sin pagarse completamente)
    prestamo_anterior = db.query(Prestamo).filter(
        Prestamo.cliente_id == prestamo.cliente_id,
        Prestamo.pagado == False
    ).order_by(Prestamo.fecha_prestamo.desc()).first()
    
    # Si hay un préstamo anterior, marcarlo como pagado
    if prestamo_anterior:
        prestamo_anterior.pagado = True
        prestamo_anterior.fecha_finalizacion = datetime.utcnow()
    
    # Cálculos para nuevo préstamo
    interes = prestamo.monto_prestado * (prestamo.interes_porcentaje / 100)
    total_deuda = prestamo.monto_prestado + interes
    valor_cartulina = (prestamo.monto_prestado / 100000) * 5000
    valor_cuota = total_deuda / prestamo.numero_cuotas
    
    # Crear nuevo préstamo
    nuevo_prestamo = Prestamo(
        cliente_id=prestamo.cliente_id,
        usuario_id=usuario_id,
        monto_prestado=prestamo.monto_prestado,
        total_deuda=total_deuda,
        deuda_restante=total_deuda,
        interes_porcentaje=prestamo.interes_porcentaje,
        valor_cartulina=valor_cartulina
    )
    db.add(nuevo_prestamo)
    db.commit()
    db.refresh(nuevo_prestamo)
    
    # Crear cuotas
    for i in range(1, prestamo.numero_cuotas + 1):
        fecha_vencimiento = calcular_fecha_vencimiento(
            date.today(), i, prestamo.frecuencia
        )
        cuota = Cuota(
            prestamo_id=nuevo_prestamo.id,
            numero_cuota=i,
            valor_cuota=valor_cuota,
            fecha_vencimiento=fecha_vencimiento,
            valor_pendiente=valor_cuota
        )
        db.add(cuota)
    db.commit()
    
    # Registrar ingreso de cartulina
    ingreso = db.query(IngresoDia).filter(
        IngresoDia.usuario_id == usuario_id,
        IngresoDia.fecha == date.today()
    ).first()
    
    if not ingreso:
        ingreso = IngresoDia(usuario_id=usuario_id)
        db.add(ingreso)

    if ingreso.ingreso_cartulinas is None:
        ingreso.ingreso_cartulinas = 0.0
    ingreso.ingreso_cartulinas += valor_cartulina
    if ingreso.ingreso_cuotas is None:
        ingreso.ingreso_cuotas = 0.0
    ingreso.total_ingresos = ingreso.ingreso_cuotas + ingreso.ingreso_cartulinas
    db.commit()
    
    return {
        "status": "success",
        "prestamo_anterior_id": prestamo_anterior.id if prestamo_anterior else None,
        "prestamo_nuevo_id": nuevo_prestamo.id,
        "total_deuda": total_deuda,
        "valor_cartulina": valor_cartulina,
        "valor_cuota": valor_cuota,
        "numero_cuotas": prestamo.numero_cuotas,
        "mensaje": f"Préstamo renovado para {cliente.nombres}"
    }

@app.get("/api/prestamos/{prestamo_id}")
def obtener_prestamo(prestamo_id: int, db: Session = Depends(get_db)):
    prestamo = db.query(Prestamo).filter(Prestamo.id == prestamo_id).first()
    if not prestamo:
        raise HTTPException(status_code=404, detail="Préstamo no encontrado")
    
    cuotas = db.query(Cuota).filter(Cuota.prestamo_id == prestamo_id).all()
    
    return {
        "prestamo": {
            "id": prestamo.id,
            "cliente_id": prestamo.cliente_id,
            "usuario_id": prestamo.usuario_id,
            "monto_prestado": prestamo.monto_prestado,
            "total_deuda": prestamo.total_deuda,
            "deuda_restante": prestamo.deuda_restante,
            "interes_porcentaje": prestamo.interes_porcentaje,
            "valor_cartulina": prestamo.valor_cartulina,
            "fecha_prestamo": prestamo.fecha_prestamo,
            "pagado": prestamo.pagado,
            "fecha_finalizacion": prestamo.fecha_finalizacion
        },
        "cuotas": [
            {
                "id": c.id,
                "prestamo_id": c.prestamo_id,
                "numero_cuota": c.numero_cuota,
                "valor_cuota": c.valor_cuota,
                "fecha_vencimiento": c.fecha_vencimiento,
                "pagada": c.pagada,
                "valor_pagado": c.valor_pagado,
                "valor_pendiente": c.valor_pendiente,
                "atrasada": c.atrasada,
                "fecha_creacion": c.fecha_creacion
            }
            for c in cuotas
        ]
    }

# ============= ENDPOINTS: COBROS =============

@app.post("/api/cobros/registrar-pago")
def registrar_pago(pago: PagoCuotaRegistro, usuario_id: int, db: Session = Depends(get_db)):
    """
    Registra el pago de una cuota.
    Los trabajadores solo pueden registrar pagos de sus clientes.
    """
    cuota = db.query(Cuota).filter(Cuota.id == pago.cuota_id).first()
    if not cuota:
        raise HTTPException(status_code=404, detail="Cuota no encontrada")
    
    prestamo = db.query(Prestamo).filter(Prestamo.id == cuota.prestamo_id).first()
    cliente = db.query(Cliente).filter(Cliente.id == prestamo.cliente_id).first()
    
    # Si es trabajador, verificar que sea su cliente
    usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if usuario and usuario.rol == RolUsuario.TRABAJADOR:
        dias_asignados = [d[0] for d in db.query(TrabajadorDia.dia).filter(TrabajadorDia.usuario_id == usuario_id).all()]
        if not dias_asignados or cliente.dia_cobro not in dias_asignados:
            raise HTTPException(status_code=403, detail="No tienes permiso para registrar pagos de este cliente")
    
    # Registrar pago
    pago_obj = PagoCuota(
        cuota_id=pago.cuota_id,
        prestamo_id=cuota.prestamo_id,
        cantidad_pagada=pago.cantidad_pagada,
        usuario_id=usuario_id
    )
    db.add(pago_obj)
    
    # Actualizar cuota
    cuota.valor_pagado += pago.cantidad_pagada
    cuota.valor_pendiente = max(0, cuota.valor_cuota - cuota.valor_pagado)
    
    if cuota.valor_pendiente == 0:
        cuota.pagada = True
    
    # Actualizar deuda del préstamo
    prestamo.deuda_restante = max(0, prestamo.deuda_restante - pago.cantidad_pagada)
    
    if prestamo.deuda_restante == 0:
        prestamo.pagado = True
        prestamo.fecha_finalizacion = datetime.utcnow()
    
    # Registrar ingreso del día
    ingreso = db.query(IngresoDia).filter(
        IngresoDia.usuario_id == usuario_id,
        IngresoDia.fecha == date.today()
    ).first()
    
    if not ingreso:
        ingreso = IngresoDia(usuario_id=usuario_id)
        db.add(ingreso)
    
    ingreso.ingreso_cuotas += pago.cantidad_pagada
    ingreso.total_ingresos = ingreso.ingreso_cuotas + ingreso.ingreso_cartulinas
    
    db.commit()
    
    return {
        "status": "success",
        "cuota_id": cuota.id,
        "cantidad_pagada": pago.cantidad_pagada,
        "cuota_pagada": cuota.pagada,
        "prestamo_finalizado": prestamo.pagado,
        "deuda_restante": prestamo.deuda_restante
    }

# ============= ENDPOINTS: INGRESOS Y GASTOS =============

@app.post("/api/gastos/registrar")
def registrar_gasto(gasto: GastoDiaRegistro, usuario_id: int, db: Session = Depends(get_db)):
    nuevo_gasto = GastoDia(
        usuario_id=usuario_id,
        concepto=gasto.concepto,
        valor=gasto.valor
    )
    db.add(nuevo_gasto)
    db.commit()
    
    return {
        "status": "success",
        "gasto_id": nuevo_gasto.id,
        "mensaje": f"Gasto de ${gasto.valor} ({gasto.concepto}) registrado"
    }

@app.get("/api/ingresos-gastos/resumen-dia")
def resumen_dia(usuario_id: int, fecha: date = None, db: Session = Depends(get_db)):
    if not fecha:
        fecha = date.today()
    
    ingreso = db.query(IngresoDia).filter(
        IngresoDia.usuario_id == usuario_id,
        IngresoDia.fecha == fecha
    ).first()
    
    gastos = db.query(GastoDia).filter(
        GastoDia.usuario_id == usuario_id,
        func.date(GastoDia.fecha_registro) == fecha
    ).all()
    
    total_gastos = sum(g.valor for g in gastos)
    total_ingresos = ingreso.total_ingresos if ingreso else 0.0
    
    return {
        "fecha": fecha,
        "ingreso_cuotas": ingreso.ingreso_cuotas if ingreso else 0.0,
        "ingreso_cartulinas": ingreso.ingreso_cartulinas if ingreso else 0.0,
        "total_ingresos": total_ingresos,
        "gastos": [{"concepto": g.concepto, "valor": g.valor} for g in gastos],
        "total_gastos": total_gastos,
        "saldo_neto": total_ingresos - total_gastos
    }

# ============= ENDPOINTS: CIERRE DE DÍA =============

@app.post("/api/cierre-dia/crear")
def crear_cierre_dia(usuario_id: int, fecha: date = None, db: Session = Depends(get_db)):
    if not fecha:
        fecha = date.today()
    
    # Verificar que el usuario es administrador
    usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if usuario.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(status_code=403, detail="Solo administradores pueden hacer cierre")
    
    ingreso = db.query(IngresoDia).filter(
        IngresoDia.usuario_id == usuario_id,
        IngresoDia.fecha == fecha
    ).first()
    
    gastos = db.query(GastoDia).filter(
        GastoDia.usuario_id == usuario_id,
        func.date(GastoDia.fecha_registro) == fecha
    ).all()
    
    total_gastos = sum(g.valor for g in gastos)
    total_ingresos = ingreso.total_ingresos if ingreso else 0.0
    
    cierre = CierreDia(
        usuario_id=usuario_id,
        fecha_cierre=fecha,
        total_cuotas_pagadas=ingreso.ingreso_cuotas if ingreso else 0.0,
        total_cartulinas=ingreso.ingreso_cartulinas if ingreso else 0.0,
        total_gastos=total_gastos,
        saldo_neto=total_ingresos - total_gastos
    )
    db.add(cierre)
    db.commit()
    
    return {
        "status": "success",
        "cierre_id": cierre.id,
        "fecha": fecha,
        "total_cuotas": cierre.total_cuotas_pagadas,
        "total_cartulinas": cierre.total_cartulinas,
        "total_gastos": cierre.total_gastos,
        "saldo_neto": cierre.saldo_neto
    }

@app.get("/api/cierre-dia/historial")
def historial_cierres(usuario_id: int, db: Session = Depends(get_db)):
    usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    
    if usuario.rol == RolUsuario.ADMINISTRADOR:
        # Admin ve todos los cierres
        cierres = db.query(CierreDia).order_by(CierreDia.fecha_cierre.desc()).all()
    else:
        # Trabajador solo ve sus cierres
        cierres = db.query(CierreDia).filter(
            CierreDia.usuario_id == usuario_id
        ).order_by(CierreDia.fecha_cierre.desc()).all()
    
    return [
        {
            "id": c.id,
            "usuario_id": c.usuario_id,
            "fecha_cierre": c.fecha_cierre,
            "total_cuotas_pagadas": c.total_cuotas_pagadas,
            "total_cartulinas": c.total_cartulinas,
            "total_gastos": c.total_gastos,
            "saldo_neto": c.saldo_neto,
            "fecha_creacion": c.fecha_creacion,
            "cerrado": c.cerrado
        }
        for c in cierres
    ]

# ============= ENDPOINTS: INFORMES =============

@app.get("/api/reportes/cliente/{cliente_id}")
def reporte_cliente(cliente_id: int, db: Session = Depends(get_db)):
    cliente = db.query(Cliente).filter(Cliente.id == cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    
    prestamos = db.query(Prestamo).filter(Prestamo.cliente_id == cliente_id).all()
    
    historial = []
    for prestamo in prestamos:
        cuotas = db.query(Cuota).filter(Cuota.prestamo_id == prestamo.id).all()
        historial.append({
            "prestamo_id": prestamo.id,
            "monto_prestado": prestamo.monto_prestado,
            "total_deuda": prestamo.total_deuda,
            "deuda_restante": prestamo.deuda_restante,
            "pagado": prestamo.pagado,
            "fecha_prestamo": prestamo.fecha_prestamo,
            "cuotas": [{
                "numero": c.numero_cuota,
                "valor": c.valor_cuota,
                "pagada": c.pagada,
                "valor_pagado": c.valor_pagado,
                "pendiente": c.valor_pendiente,
                "atrasada": c.atrasada,
                "vencimiento": c.fecha_vencimiento
            } for c in cuotas]
        })
    
    return {
        "cliente": {
            "id": cliente.id,
            "nombres": cliente.nombres,
            "cedula": cliente.cedula,
            "telefono": cliente.telefono,
            "usuario_id": cliente.usuario_id,
            "trabajador_id": cliente.trabajador_id,
            "dia_cobro": cliente.dia_cobro,
            "fecha_creacion": cliente.fecha_creacion,
            "activo": cliente.activo
        },
        "historial_prestamos": historial,
        "resumen": {
            "total_prestamos": len(prestamos),
            "prestamos_completos": sum(1 for p in prestamos if p.pagado),
            "deuda_total": sum(p.deuda_restante for p in prestamos if not p.pagado),
            "prestamos_atrasados": sum(1 for p in prestamos if not p.pagado and any(c.atrasada for c in db.query(Cuota).filter(Cuota.prestamo_id == p.id).all()))
        }
    }

@app.get("/")
@app.head("/")
def inicio():
    return {"mensaje": "Servidor de Cobros Activo", "version": "1.0.1"}