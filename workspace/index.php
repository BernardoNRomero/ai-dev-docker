<?php

declare(strict_types=1);

header('Content-Type: text/html; charset=utf-8');

$checks = [
    'PHP' => PHP_VERSION,
    'Timezone' => date_default_timezone_get(),
];
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>AI Dev</title>
    <link rel="stylesheet" href="assets/styles.css">
</head>
<body>
    <main>
        <h1>Entorno listo</h1>
        <p>Apache y PHP responden. El codigo del proyecto vive en esta carpeta.</p>
        <ul>
            <?php foreach ($checks as $label => $value): ?>
                <li><strong><?= htmlspecialchars($label, ENT_QUOTES, 'UTF-8') ?>:</strong> <?= htmlspecialchars($value, ENT_QUOTES, 'UTF-8') ?></li>
            <?php endforeach; ?>
        </ul>
    </main>
</body>
</html>
