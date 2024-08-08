const express = require("express");
const Router = express.Router();
const pool = require("../db.js");
const jwt = require("jsonwebtoken");
const dotenv = require("dotenv");
const crypto = require('crypto');
const { validateCookie } = require("../middlewares/authorization.js");

dotenv.config();

function decodificarTokenParaID(req) {
    const cookieHeader = req.body.cookie;
    const cookies = cookieHeader.split(';').reduce((acc, cookie) => {
        const [key, value] = cookie.split('=').map(c => c.trim());
        acc[key] = value;
        return acc;
    }, {});
    const token = cookies.jwt;

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

Router.get("/TablaUsuarios", async (req, res) => {
    try {
        const [result] = await pool.query("SELECT * FROM Usuarios");
        res.status(200).send(result);
    } catch (err) {
        res.status(500).send("No se pudo obtener la tabla de Usuarios");
    }
});

Router.post("/Registro", async (req, res) => {
    const { NombreUsuario, Contraseña, ApellidoUsuario, CorreoUsuario, FECHA_NACIMIENTO } = req.body;
    try {
        await pool.query(
            `INSERT INTO Usuarios (NombreUsuario, Contraseña, ApellidoUsuario, CorreoUsuario, FECHA_NACIMIENTO)
            VALUES (?, ?, ?, ?, ?)`,
            [NombreUsuario, Contraseña, ApellidoUsuario, CorreoUsuario, FECHA_NACIMIENTO]
        );
        res.status(200).send("Usuario registrado exitosamente");
    } catch (err) {
        res.status(500).send("Error al registrar usuario");
    }
});

Router.post("/ActualizarDatos", async (req, res) => {
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
        await pool.query(query, values);
        res.status(200).json({ message: 'Datos actualizados correctamente' });
    } catch (err) {
        res.status(500).send('Error al actualizar los datos');
    }
});

Router.post("/MostrarDatosUsuario", async (req, res) => {
    try {
        const idUsuario = decodificarTokenParaID(req, res);
        const query = `
            SELECT idusuario, NombreUsuario, ApellidoUsuario, CorreoUsuario, SOBREMI FROM usuarios WHERE idusuario = ?
        `;
        const [result] = await pool.query(query, [idUsuario]);
        res.status(200).json(result);
    } catch (err) {
        res.status(500).send('Error al obtener los datos');
    }
});

Router.post("/insFotoPerfil", async (req, res) => {
    const { FotoPerfil } = req.body;
    try {
        const idUsuario = decodificarTokenParaID(req, res);
        await pool.query(`INSERT INTO IMAGENESUSUARIO (IDIMAGENUSUARIO, idusuario) VALUES (?, ?)`, [FotoPerfil, idUsuario]);
        res.status(200).send('Foto de perfil insertada correctamente');
    } catch (err) {
        res.status(500).send('Error al insertar la foto de perfil');
    }
});

Router.get("/obtFotoPerfil", async (req, res) => {
    try {
        const idUsuario = decodificarTokenParaID(req, res);
        const query = `
            SELECT 
                (SELECT NOMBREIMAGEN FROM USUARIOS WHERE idusuario = ?) AS FotoPerfil
        `;
        const [result] = await pool.query(query, [idUsuario]);
        res.status(200).json(result[0]);
    } catch (err) {
        res.status(500).send('Error al obtener los datos');
    }
});

Router.post("/IniciarSesion", async (req, res) => {
    const { CorreoUsuario, Contraseña } = req.body;
    const encryptedPassword = crypto.createHash('md5').update(Contraseña).digest('hex');
    try {
        const [result] = await pool.query('SELECT idusuario FROM Usuarios WHERE CorreoUsuario = ? AND Contraseña = ?', [CorreoUsuario, encryptedPassword]);
        if (result.length > 0) {
            const idUsuario = result[0].idusuario;
            const token = jwt.sign({ idUsuario }, process.env.jwtSecret, { expiresIn: process.env.jwtExpiresIn });
            const cookieOptions = {
                expires: new Date(Date.now() + (process.env.CookieExpiration * 24 * 60 * 60 * 1000)),
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
        } else {
            res.status(401).send("Correo o contraseña incorrectos");
        }
    } catch (err) {
        res.status(500).send("Error al iniciar sesión");
    }
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

Router.post('/MostrarDinero', async (req, res) => {
    try {
        const idUsuario = decodificarTokenParaID(req, res);
        const query = `
        SELECT 
            (SELECT SUM(MontoIngreso) FROM Ingresos_Mensuales WHERE FKusuario = ?) AS Ingresos,
            (SELECT SUM(MontoEgreso) FROM Egresos_Mensuales WHERE FKusuario = ?) AS Egresos,
            (SELECT CantidadActual FROM CantidadActual WHERE FKusuario = ? ORDER BY FechaCantidadActual DESC LIMIT 1) AS DineroActual
        `;
        const [result] = await pool.query(query, [idUsuario, idUsuario, idUsuario]);
        res.status(200).json(result[0]);
    } catch (err) {
        res.status(500).send('Error al obtener los datos');
    }
});

Router.post('/AgregarServicio', async (req, res) => {
    try {
        const idUsuario = decodificarTokenParaID(req, res);
        const { Nombre, Precio } = req.body;

        const queryGetServiceId = `SELECT idservicios FROM Servicios WHERE idUsuario = ?`;
        const [result] = await pool.query(queryGetServiceId, [idUsuario]);
        const idServicio = result[0].idservicios;

        const queryInsertService = `INSERT INTO ServiciosStreaming (nombreservicio, precioservicio, idservicio) VALUES (?, ?, ?)`;
        await pool.query(queryInsertService, [Nombre, Precio, idServicio]);
        res.status(200).send('Servicio insertado correctamente');
    } catch (err) {
        res.status(500).send('Error al insertar el servicio de streaming');
    }
});

Router.post('/MostrarServicios', async (req, res) => {
    try {
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
        const [result] = await pool.query(query, [idUsuario]);
        res.status(200).json(result);
    } catch (err) {
        res.status(500).send('Error al obtener los servicios');
    }
});

Router.post('/MostrarComprasIndividuales', async (req, res) => {
    try {
        const idUsuario = decodificarTokenParaID(req, res);
        const query = `SELECT NombreGasto, CantidadGasto, PrecioGasto FROM Gastos WHERE FKusuario = ?`;
        const [result] = await pool.query(query, [idUsuario]);
        res.status(200).json(result);
    } catch (err) {
        res.status(500).send('Error al obtener los datos');
    }
});

Router.post('/IngresarCompra', async (req, res) => {
    try {
        const idUsuario = decodificarTokenParaID(req, res);
        const { NombreGasto, CantidadGasto, PrecioGasto } = req.body;
        await pool.query(`INSERT INTO Gastos (NombreGasto, CantidadGasto, PrecioGasto, FKusuario) VALUES (?, ?, ?, ?)`, [NombreGasto, CantidadGasto, PrecioGasto, idUsuario]);
        res.status(200).send('Compra insertada correctamente');
    } catch (err) {
        res.status(500).send('Error al insertar la compra');
    }
});

Router.post('/MostrarGastos12Ultimosmeses', async (req, res) => {
    try {
        const idUsuario = decodificarTokenParaID(req, res);
        const query = `
            SELECT MontoTotal as value, FechaRegistro AS time
            FROM RegistroMensual
            WHERE FKusuario = ?
            AND FechaRegistro >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
            ORDER BY FechaRegistro ASC
        `;
        const [result] = await pool.query(query, [idUsuario]);
        const formattedResult = result.map(r => {
            const formattedTime = r.time.toISOString().split('T')[0];
            return { value: r.value, time: formattedTime };
        });
        res.status(200).send(formattedResult);
    } catch (err) {
        res.status(500).json({ error: 'Error al obtener los datos' });
    }
});

Router.post('/ActualizarIngresoMensual', async (req, res) => {
    try {
        const idUsuario = decodificarTokenParaID(req, res);
        const { Ingreso } = req.body;
        await pool.query(`UPDATE Ingresos_Mensuales SET MontoIngreso = ? WHERE FKusuario = ?`, [Ingreso, idUsuario]);
        res.status(200).send('Ingreso mensual actualizado correctamente');
    } catch (err) {
        res.status(500).send('Error al actualizar el ingreso mensual');
    }
});

Router.post('/IngresarIngresoIndividual', async (req, res) => {
    try {
        const idUsuario = decodificarTokenParaID(req, res);
        const { Nombre, Monto } = req.body;
        await pool.query(`INSERT INTO Ingreso (NombreIngreso, MontoIngreso, FKusuario) VALUES (?, ?, ?)`, [Nombre, Monto, idUsuario]);
        res.status(200).send('Ingreso insertado correctamente');
    } catch (err) {
        res.status(500).send('Error al insertar el ingreso');
    }
});

module.exports = Router;




