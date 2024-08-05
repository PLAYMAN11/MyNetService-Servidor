const mysql = require('mysql2');

const pool = mysql.createPool({
        host: '193.203.166.204',
        user: 'u359191253_Emmanuel',
        password: 'qhmQMBu2E',
        database: 'u359191253_MynetService',
        port: '3306',
        waitForConnections: true,
        connectionLimit: 10,
        queueLimit: 0
    });

module.exports = pool.promise();

