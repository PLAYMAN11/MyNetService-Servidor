const mysql = require('mysql2');

function createConnection() {
    return mysql.createConnection({
        host: '193.203.166.204',
        user: 'u359191253_Emmanuel',
        password: 'qhmQMBu2E',
        database: 'u359191253_MynetService',
        port: '3306',
    });
}

module.exports = { createConnection };

