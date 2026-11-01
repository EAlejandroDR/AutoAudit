#  AutoAudit - Sistema de Auditoría Automatizado

Proyecto desarrollado para el curso de Bases de Datos en la Universidad Mariano Gálvez de Guatemala.

# Ingeniero:
Edgar Rene Ornelis Hoil

# Integrantes del Grupo:
Eduardo ALejandro Dardon Ramirez
Elian Josue David Cordova Orrego
Wilmer Orlando Garcia Salazar
Byron Rene Resuleu Hernandez

##  Descripción
AutoAudit es un sistema configurable que permite monitorear y rastrear cambios (`INSERT`, `UPDATE`, `DELETE`) en tablas y columnas de una base de datos PostgreSQL 18, registrando el historial completo en una bitácora centralizada.

##  Requisitos Técnicos
- **Base de Datos:** PostgreSQL 18
- **Sistema Operativo:** Ubuntu 26.04 LTS
- **Lenguajes:** PL/pgSQL, Python 3.10+ (Flask)

## Estructura del Repositorio
- `/sql`: Scripts de creación de base de datos, triggers dinámicos, seguridad y pruebas de rendimiento.
- `/src`: Aplicación web interactiva en Flask para administración de auditoría y consultas históricas.
- `/docs`: Documentación en formato PDF.

