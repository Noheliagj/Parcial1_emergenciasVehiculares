from pydantic import BaseModel
from typing import Optional

# Este es el "formulario" que el cliente llenará en su App (Flutter)
class ClienteNuevo(BaseModel):
    nombre_completo: str
    telefono: str
    email: str
    contrasena: str
# --- FORMULARIO PARA VEHÍCULOS (CU-02) ---
class VehiculoNuevo(BaseModel):
    placa: str
    marca: str
    modelo: str
    color: str
    cliente_id: int  # ¡Súper importante! Esto nos dice de quién es el auto

# --- FORMULARIO PARA TALLERES (CU-03) ---
class TallerNuevo(BaseModel):
    nombre_taller: str
    direccion: str
    telefono: str
    email: str
    contrasena: str

# --- FORMULARIO PARA TÉCNICOS (CU-04) ---
class TecnicoNuevo(BaseModel):
    nombre_completo: str
    especialidad: str
    taller_id: int # Para saber en qué taller trabaja este mecánico
# --- FORMULARIO PARA EMERGENCIAS (CU-05) ---

class EmergenciaNueva(BaseModel):
    cliente_id: int
    vehiculo_id: int
    direccion: str
    descripcion: str
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    tipo_ia: Optional[str] = None
    severidad_ia: Optional[str] = None

class EmergenciaResponse(EmergenciaNueva):
    id: int
    estado: str
    class Config:
        from_attributes = True
# --- FORMULARIO PARA INICIAR SESIÓN ---
class LoginTaller(BaseModel):
    email: str
    contrasena: str
# --- FORMULARIO PARA CREAR CLIENTE ---
class ClienteCreate(BaseModel):
    nombre_completo: str  # <--- ¡Corregido!
    email: str
    contrasena: str
    telefono: str

class LoginCliente(BaseModel):
    email: str
    contrasena: str

class VehiculoCreate(BaseModel):
    placa: str
    marca: str
    modelo: str
    color: str
    cliente_id: int 