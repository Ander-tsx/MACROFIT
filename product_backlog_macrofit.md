# Product Backlog — MacroFit

## Información General del Proyecto

| Campo | Detalle |
| :--- | :--- |
| **Proyecto** | MacroFit |
| **Product Owner** | Contreras Cortés César Emilio |
| **Versión** | 1.0 |
| **Fecha** | 26/09/2026 |
| **Fuente** | Especificación de Requerimientos de Software (SRS) v1.0 |

---

## 1. Historias Técnicas / Tareas de Infraestructura

| ID | Historia Técnico-Arquitectónica | Prioridad | SP |
| :--- | :--- | :---: | :---: |
| **TEC-01** | Configurar el proyecto Flutter, el repositorio en GitHub, la estrategia de ramas y la plantilla de pull request. | Must | 3 |
| **TEC-02** | Spike: comparar al menos 3 servicios de reconocimiento de alimentos (precisión, latencia, costo). | Must | 5 |
| **TEC-03** | Spike: seleccionar backend y base de datos. | Must | 3 |
| **TEC-04** | Definir la arquitectura de la app: capas, gestión de estado y estructura de carpetas. | Must | 3 |
| **TEC-05** | Configurar el backend: autenticación, base de datos, almacenamiento de fotos y reglas de acceso base. | Must | 5 |
| **TEC-06** | Elaborar el diagrama entidad-relación y crear el esquema en la base de datos. | Must | 2 |
| **TEC-07** | Redactar el aviso de privacidad para datos de salud y fotografías. | Must | 2 |
| **TEC-08** | Diseñar el mapa de navegación para ambos roles. | Must | 5 |
| **TEC-09** | Cargar el catálogo inicial de ejercicios. | Must | 3 |
| **TEC-10** | Implementar el motor de reglas para generar rutinas por objetivo, nivel y disponibilidad. | Must | 8 |

---

## 2. Historias de Usuario (Funcionales)

### Épica: Autenticación
| ID | Historia de Usuario | RF | Prioridad | SP |
| :--- | :--- | :---: | :---: | :---: |
| **HU-01** | Como persona nueva, quiero crear una cuenta eligiendo mi rol para acceder a las funciones de coach o de usuario. | RF-01 | Must | 3 |
| **HU-02** | Como usuario o coach, quiero iniciar y cerrar sesión para proteger mi información. | RF-02 | Must | 2 |

### Épica: Perfil y Metas
| ID | Historia de Usuario | RF | Prioridad | SP |
| :--- | :--- | :---: | :---: | :---: |
| **HU-03** | Como usuario, quiero capturar mi perfil inicial para recibir metas y rutinas acordes a mí. | RF-03 | Must | 3 |
| **HU-04** | Como usuario, quiero que el sistema calcule mi meta nutricional para tener una referencia diaria. | RF-04 | Must | 3 |
| **HU-05** | Como coach, quiero definir y ajustar las metas de calorías y macros de cada cliente para personalizar su plan. | RF-21 | Must | 3 |

### Épica: Registro Nutricional
| ID | Historia de Usuario | RF | Prioridad | SP |
| :--- | :--- | :---: | :---: | :---: |
| **HU-06** | Como usuario, quiero tomar o seleccionar una foto de mi comida para registrarla. | RF-05 | Must | 2 |
| **HU-07** | Como usuario, quiero que el sistema estime las calorías, proteína y grasa de mi foto para no capturarlas manualmente. | RF-06 | Must | 5 |
| **HU-08** | Como usuario, quiero corregir los valores estimados antes de guardar para que mi registro sea preciso. | RF-07 | Must | 2 |
| **HU-09** | Como usuario, quiero guardar y eliminar mis registros de comida para mantener mi historial correcto. | RF-08 | Must | 3 |

### Épica: Resumen Nutricional
| ID | Historia de Usuario | RF | Prioridad | SP |
| :--- | :--- | :---: | :---: | :---: |
| **HU-10** | Como usuario, quiero ver mi consumo del día comparado con mi meta para saber cuánto me falta. | RF-09 | Must | 3 |
| **HU-11** | Como usuario, quiero ver mi resumen semanal para identificar tendencias. | RF-10 | Should | 3 |

### Épica: Vinculación
| ID | Historia de Usuario | RF | Prioridad | SP |
| :--- | :--- | :---: | :---: | :---: |
| **HU-12** | Como coach, quiero tener un código de invitación para que mis clientes se vinculen conmigo. | RF-11 | Must | 2 |
| **HU-13** | Como usuario, quiero vincularme con un coach mediante su código para recibir seguimiento. | RF-12 | Must | 3 |
| **HU-14** | Como usuario, quiero desvincularme de mi coach para dejar de compartir mis datos. | RF-13 | Should | 2 |

### Épica: Rutinas
| ID | Historia de Usuario | RF | Prioridad | SP |
| :--- | :--- | :---: | :---: | :---: |
| **HU-15** | Como usuario, quiero recibir rutinas recomendadas según mi objetivo, nivel y disponibilidad para entrenar sin coach. | RF-14 | Must | 5 |
| **HU-16** | Como usuario, quiero ver mis rutinas identificando si son recomendadas o asignadas para saber cuál seguir. | RF-15 | Must | 3 |
| **HU-17** | Como usuario, quiero marcar una sesión como completada para registrar mi cumplimiento. | RF-16 | Must | 2 |
| **HU-18** | Como coach, quiero crear rutinas personalizadas para adaptarlas a cada cliente. | RF-22 | Must | 5 |
| **HU-19** | Como coach, quiero asignar una rutina a uno o varios clientes para que la sigan. | RF-23 | Must | 3 |
| **HU-20** | Como coach, quiero modificar o retirar una rutina asignada para ajustarla al avance del cliente. | RF-24 | Should | 3 |

### Épica: Progreso
| ID | Historia de Usuario | RF | Prioridad | SP |
| :--- | :--- | :---: | :---: | :---: |
| **HU-21** | Como usuario, quiero registrar mi peso para seguir mi evolución. | RF-17 | Should | 2 |
| **HU-22** | Como usuario, quiero ver gráficas de peso, macros y cumplimiento para visualizar mi progreso. | RF-18 | Should | 5 |
| **HU-23** | Como coach, quiero ver el progreso histórico de cada cliente para evaluar su adherencia. | RF-25 | Should | 3 |

### Épica: Gestión de Clientes
| ID | Historia de Usuario | RF | Prioridad | SP |
| :--- | :--- | :---: | :---: | :---: |
| **HU-24** | Como coach, quiero ver la lista de mis clientes para acceder a su información. | RF-19 | Must | 2 |
| **HU-25** | Como coach, quiero consultar el registro diario de comidas de un cliente para revisar su alimentación. | RF-20 | Must | 3 |

---

## 3. Resumen y Métricas del Backlog

| Tipo | Cantidad de Elementos | Story Points Total (SP) |
| :--- | :---: | :---: |
| **Historias Técnicas** | 10 | 39 |
| **Historias de Usuario** | 25 | 75 |
| **Total** | **35** | **114** |

---

### Distribución por Prioridad (MoSCoW)

* **Must Have:** 28 historias / 94 SP
* **Should Have:** 7 historias / 20 SP