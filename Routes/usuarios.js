const express = require("express");
const Router = express.Router();
const { createConnection } = require("../db.js");
const jwt = require("jsonwebtoken");
const dotenv = require("dotenv");
const { status } = require("init");
const { send } = require("process");
const { Domain } = require("domain");
const { log, error } = require("console");
const { validateCookie } = require("../middlewares/authorization.js");
const crypto = require('crypto');
const { run } = require("node:test");


const RUN = createConnection();
dotenv.config();

function decodificarTokenParaID(req) {
    const cookieHeader = req.body.cookie;
    const cookies = cookieHeader.split(';').reduce((acc, cookie) => {
        const [key, value] = cookie.split('=').map(c => c.trim());
        acc[key] = value;
        return acc;
    }, {});
    const token = cookies.jwt; // Suponiendo que el token se llama 'token' en la cookie

    if (!token) {
        throw new Error('No se encontró el token en la cookie');
    }

    let idUsuario;
    try {
        const decoded = jwt.verify(token, process.env.jwtSecret);
        idUsuario = decoded.idUsuario;
    } catch (err) {
        throw new Error('Token inválido');
    }
    return idUsuario;
}

Router.get("/TablaUsuarios", (req, res) => {
RUN.query("SELECT * FROM usuarios", (err, result) => {
    if (err) {
       res.status(500).send("No se pudo obtener la tabla de usuarios");
    } else {
       res.status(200).send(result);
       }
});
});

Router.post("/Registro", (req, res) => {
    const { NombreUsuario, Contraseña, ApellidoUsuario, CorreoUsuario, FECHA_NACIMIENTO } = req.body;
    RUN.query(`INSERT INTO usuarios (NombreUsuario, Contraseña, ApellidoUsuario, CorreoUsuario, FECHA_NACIMIENTO)
VALUES (?, ?, ?, ?, ?)`, [NombreUsuario, Contraseña, ApellidoUsuario, CorreoUsuario, FECHA_NACIMIENTO], 
(err, result) => {
        if (err) {
            res.status(500).send("Error al registrar usuario");
        } else {
            res.status(200).send("Usuario registrado exitosamente");
        }
    });
});

Router.post("/ActualizarDatos", (req, res) => {
    try {
        const idUsuario = decodificarTokenParaID(req, res);
        if (!idUsuario) {
            return res.status(400).send('Invalid user ID');
        }
        let queryParams = '';
        let values = [];
        for (const key in req.body) {
            if (req.body.hasOwnProperty(key) && key !== 'cookie' && req.body[key] !== '') {
            queryParams += `${key} = ?, `;
            values.push(req.body[key]);
            }
        }
        queryParams = queryParams.slice(0, -2);
        values.push(idUsuario);

        const query = `UPDATE Usuarios SET ${queryParams} WHERE idusuario = ?`;
        console.log('Executing query:', query);
        console.log('With values:', values);

        RUN.query(query, values, (err, result) => {
            if (err) {
                console.error('Error executing query:', err);
                return res.status(500).send('Error al actualizar los datos');
            } else {
                return res.status(200).json(result);
            }
        });
    } catch (error) {
        console.error('Unexpected error:', error);
        return res.status(500).send('Unexpected error occurred');
    }
});

Router.post("/MostrarDatosUsuario", (req, res) => {
    const idUsuario = decodificarTokenParaID(req, res);
    const query = `
            SELECT idusuario, NombreUsuario, ApellidoUsuario, CorreoUsuario, SOBREMI FROM USUARIOS WHERE idusuario = ?
        `;
    RUN.query(query,[idUsuario], (err, result) => {
        if (err) {
            res.status(500).send('Error al obtener los datos');
        } else {
            res.status(200).json(result);
        }
    });
});

Router.post("/insFotoPerfil", (req, res) => {
    const { FotoPerfil } = req.body;
    const idUsuario = decodificarTokenParaID(req, res);
    console.log('El id usuario es: ', idUsuario);
    RUN.query(`INSERT INTO IMAGENESUSUARIO SET IDIMAGENUSUARIO = ? WHERE idusuario = ?`, [FotoPerfil, idUsuario], (err, result) => {
        if (err) {
            res.status(500).send('Error al insertar la foto de perfil');
        } else {
            res.status(200).send('Foto de perfil insertada correctamente');
        }
    });
});

Router.get("/obtFotoPerfil", (req, res) => {
    const idUsuario = decodificarTokenParaID(req, res);
    console.log('El id usuario es: ', idUsuario);
    const query = `
        SELECT 
            (SELECT NOMBREIMAGEN FROM USUARIOS WHERE idusuario = ?) AS FotoPerfil
    `;
    RUN.query(query,[idUsuario], (err, result) => {
        if (err) {
            res.status(500).send('Error al obtener los datos');
        } else {
            res.status(200).json(result[0]);
        }
    });
});

Router.post("/IniciarSesion", (req, res) => {
    const { CorreoUsuario, Contraseña } = req.body;
    const encryptedPassword = crypto.createHash('md5').update(Contraseña).digest('hex');
    RUN.query('SELECT idusuario FROM usuarios WHERE CorreoUsuario = ? AND Contraseña = ?', [CorreoUsuario, encryptedPassword], (err, result) => {
        if (err) {
            console.error("Error en la consulta:", err); // Log de error
            res.status(500).send("Sesion no encontrada");
        } else {
            console.log("Resultado de la consulta:", result); // Log del resultado
            if (result.length > 0) {
                const idUsuario = result[0].idusuario;

                try {
                    const token= jwt.sign(
                        { idUsuario },
                        process.env.jwtSecret,
                        { expiresIn: process.env.jwtExpiresIn }
                    );
                    const cookieOptions = {
                        expires: (process.env.CookieExpiration * 24 * 60 * 60 * 1000),
                        path: '/',
                        secure: false,
                        httpOnly: true
                    };
                    res.status(200).json({
                        token: token,
                        expires: cookieOptions.expires,
                        path: cookieOptions.path,
                        secure: cookieOptions.secure,
                        httpOnly: cookieOptions.httpOnly,
                      });
                } catch (error) {
                    console.error("Error al generar el token:", error); // Log de error al generar el token
                    res.status(500).send("Error al iniciar sesión");
                }
            } else {
                res.status(401).send("Correo o contraseña incorrectos");
            }
        }
    });
});

Router.post('/rqCookieUsuario', (req, res) => {
    const { cookie } = req.body;

    if (validateCookie(cookie)) {
        res.status(200).send('Autenticación exitosa');
    } else {
res.status(401).send('Autenticación fallida');
    }
});

Router.post('/rqCookieGuest', (req, res) => {
    const { cookie } = req.body;

    if (validateCookie(cookie)) {
        res.status(200).send('Autenticación exitosa');
    } else {
        res.status(401).send('Autenticación fallida');
    }
});

Router.post('/MostrarDinero', (req, res) => {
    const idUsuario = decodificarTokenParaID(req, res);
    console.log('El id usuario es: ', idUsuario);
    const query = `
    SELECT 
        (SELECT SUM(MontoIngreso) FROM Ingresos_Mensuales WHERE FKusuario = ?) AS Ingresos,
        (SELECT SUM(MontoEgreso) FROM Egresos_Mensuales WHERE FKusuario = ?) AS Egresos,
        (SELECT CantidadActual FROM CantidadActual WHERE FKusuario = ? ORDER BY FechaCantidadActual DESC LIMIT 1) AS DineroActual
`;
    RUN.query(query, [idUsuario, idUsuario, idUsuario], (err, result) => {
        if (err) {
            res.status(500).send('Error al obtener los datos');
        } else {
            res.status(200).json(result[0]);
        }
    });
});

Router.post('/AgregarServicio', (req, res) => {
    const idUsuario = decodificarTokenParaID(req, res);
    const { Nombre, Precio } = req.body;
        // el id del servicio correspondiente al usuario
        const queryGetServiceId = `
        SELECT idservicios 
        FROM Servicios 
        WHERE idUsuario = ?;
    `;

    RUN.query(queryGetServiceId, [idUsuario], (err, result) => {
        const idServicio = result[1].idservicios;
        // Luego, insertamos el nuevo servicio de streaming
        const queryInsertService = `
            INSERT INTO ServiciosStreaming (nombreservicio, precioservicio, idservicio)
            VALUES (?, ?, ?);
        `;

        RUN.query(queryInsertService, [Nombre, Precio, idServicio], (err, result) => {
            if (err) {
                // Manejo de errores
                res.status(500).send('Error al insertar el servicio de streaming');
                return;
            }

            // Inserción exitosa
            res.status(200).send('Servicio insertado correctamente');
        });
    });
});

Router.post('/MostrarServicios', (req, res) => {
    const idUsuario = decodificarTokenParaID(req, res);
    const query = `
        SELECT 
            ss.nombreservicio as nombre,
            ss.precioservicio as precio
        FROM 
            ServiciosStreaming ss
        JOIN 
            Servicios s ON ss.idservicio = s.idservicios
        WHERE 
            s.idUsuario = ?
    `;

    RUN.query(query, [idUsuario], (err, result) => {
        if (err) {
            console.error('Error al obtener los servicios:', err); // Añadir log para errores
            res.status(500).send('Error al obtener los servicios');
        } else {
              res.status(200).json(result);
        }
    });
});

Router.post('/MostrarComprasIndividuales', (req, res) => {
    const idUsuario = decodificarTokenParaID(req, res);
    const query = `
        SELECT NombreGasto,  
        CantidadGasto, PrecioGasto
        FROM Gastos WHERE FKusuario = ?;
    `;
    RUN.query(query, [idUsuario], (err, result) => {
        if (err) {
            res.status(500).send('Error al obtener los datos');
        } else {
            res.status(200).json(result);
        }
    });
});

Router.post('/IngresarCompra', (req, res) => {
    const idUsuario = decodificarTokenParaID(req, res);
    const { NombreGasto, CantidadGasto, PrecioGasto } = req.body;
    RUN.query(`INSERT INTO Gastos (NombreGasto, CantidadGasto, PrecioGasto, FKusuario) VALUES (?, ?, ?, ?)`, [NombreGasto, CantidadGasto, PrecioGasto, idUsuario], (err, result) => {
        if (err) {
            res.status(500).send('Error al insertar la compra');
        } else {
            res.status(200).send('Compra insertada correctamente');
        }
    });
});

Router.post('/MostrarGastos12Ultimosmeses', (req, res) => {
    const idUsuario = decodificarTokenParaID(req, res);
    const query = `
        SELECT MontoTotal as value, FechaRegistro AS time
        FROM RegistroMensual
        WHERE FKusuario = ?
        AND FechaRegistro >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
        ORDER BY FechaRegistro ASC
    `;
    RUN.query(query, [idUsuario], (error, resultados) => {
        if (error) {
            console.log ('Error al obtener los datos', error);
            return res.status(500).json({ error: 'Error al obtener los datos', error});
        }
        const formattedResult = resultados.map(result => {
            const formattedTime = result.time.toISOString().split('T')[0];
            return { value: result.value, time: formattedTime };
        });
        res.status(200).send(formattedResult);
        console.log('Resultados:', formattedResult);
    });
});

Router.post('/ActualizarIngresoMensual', (req, res) => {
    const idUsuario = decodificarTokenParaID(req, res);
    const { Ingreso } = req.body;
    RUN.query(`UPDATE Ingresos_Mensuales SET MontoIngreso = ? WHERE FKusuario = ?`, [Ingreso, idUsuario], (err, result) => {
        if (err) {
            res.status(500).send('Error al actualizar el ingreso mensual');
        } else {
            res.status(200).send('Ingreso mensual actualizado correctamente');
        }
    });
});

Router.post('/IngresarIngresoIndividual', (req, res) => {
    const idUsuario = decodificarTokenParaID(req, res);
    const { Nombre, Monto } = req.body;
    RUN.query(`INSERT INTO Ingreso (NombreIngreso, MontoIngreso, FKusuario) VALUES (?, ?, ?)`, 
        [Nombre, Monto, idUsuario], (err, result) => {
        if (err) {
            res.status(500).send('Error al insertar el ingreso');
        } else {
            res.status(200).send('Ingreso insertada correctamente');
        }
    });
});

module.exports = Router;



