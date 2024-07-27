const express = require("express");
const Router = express.Router();
const { createConnection } = require("../db.js");
const jwt = require("jsonwebtoken");
const dotenv = require("dotenv");
const { status } = require("init");
const { send } = require("process");
const { Domain } = require("domain");
const { log } = require("console");
const { validateCookie } = require("../middlewares/authorization.js");


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
    const { NombreUsuario, Contraseña, ApellidoUsuario, CorreoUsuario, Telefono, FECHA_NACIMIENTO } = req.body;
    RUN.query(`INSERT INTO usuarios (NombreUsuario, Contraseña, ApellidoUsuario, CorreoUsuario, Telefono, Estado, FECHA_NACIMIENTO)
VALUES (?, ?, ?, ?, ?, "Activo", ?)`, [NombreUsuario, Contraseña, ApellidoUsuario, CorreoUsuario, Telefono, FECHA_NACIMIENTO], 
(err, result) => {
        if (err) {
            res.status(500).send("Error al registrar usuario");
        } else {
            res.status(200).send("Usuario registrado exitosamente");
        }
    });
});

Router.post("/insAgregarSobremi", (req, res) => {
    const { SOBREMI } = req.body;
    RUN.query(`INSERT INTO usuarios (SOBREMI) values (?)`,[SOBREMI],
        (err, result) => {
        if (err) {
           res.status(500).send("Error al ingresar Notas");
        } else {
           res.status(200).send("Notas ingresado exitosamente");
           }
    });
});


Router.get("/nombreUsuarioPerfil", (req, res) => {
    const idUsuario = decodificarTokenParaID(req, res);
    console.log('El id usuario es: ', idUsuario);
    const query = `
        SELECT 
            (SELECT NombreUsuario FROM USUARIOS WHERE idusuario = ?) AS NombreUsuario
    `;
    RUN.query(query,[idUsuario], (err, result) => {
        if (err) {
            res.status(500).send('Error al obtener los datos');
        } else {
            res.status(200).json(result[0]);
        }
    });
});

Router.get("/obtSobremiPerfil", (req, res) => {
    const idUsuario = decodificarTokenParaID(req, res);
    console.log('El id usuario es: ', idUsuario);
    const query = `
        SELECT 
            (SELECT SOBREMI FROM USUARIOS WHERE idusuario = ?) AS Ingresos
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

    RUN.query('SELECT idusuario FROM usuarios WHERE CorreoUsuario = ? AND Contraseña = ?', [CorreoUsuario, Contraseña], (err, result) => {
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
            (SELECT MontoIngreso FROM Ingresos_Mensuales WHERE FKusuario = ?) AS Ingresos,
            (SELECT MontoEgreso FROM Egresos_Mensuales WHERE FKusuario = ?) AS Egresos,
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

module.exports = Router;


