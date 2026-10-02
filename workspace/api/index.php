<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

/** @param array<string, mixed> $payload */
function respond(int $status, array $payload): never
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

/**
 * @param array<string, mixed> $payload
 * @return array<array-key, mixed>
 */
function requestAi(string $url, array $payload, ?string $apiKey = null): array
{
    $headers = [
        'Content-Type: application/json',
        'Accept: application/json',
    ];
    if ($apiKey !== null && $apiKey !== '') {
        $headers[] = 'Authorization: Bearer ' . $apiKey;
    }

    $context = stream_context_create([
        'http' => [
            'method' => 'POST',
            'header' => implode("\r\n", $headers),
            'content' => json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR),
            'timeout' => 240,
            'ignore_errors' => true,
        ],
    ]);
    $response = @file_get_contents($url, false, $context);
    if ($response === false) {
        $lastError = error_get_last();
        error_log('AI API connection failed: ' . ($lastError['message'] ?? 'unknown transport error'));
        respond(502, ['ok' => false, 'error' => 'No se pudo conectar con el proveedor de IA']);
    }

    $statusLine = $http_response_header[0] ?? '';
    preg_match('/\s(\d{3})\s/', $statusLine, $matches);
    $status = isset($matches[1]) ? (int) $matches[1] : 0;
    if ($status < 200 || $status >= 300) {
        error_log('AI API returned HTTP status ' . $status);
        respond(502, ['ok' => false, 'error' => 'El proveedor de IA devolvió un error']);
    }

    try {
        $decoded = json_decode($response, true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException) {
        error_log('AI API returned invalid JSON');
        respond(502, ['ok' => false, 'error' => 'El proveedor de IA devolvió una respuesta inválida']);
    }

    if (!is_array($decoded)) {
        error_log('AI API returned an unexpected response shape');
        respond(502, ['ok' => false, 'error' => 'El proveedor de IA devolvió una respuesta inválida']);
    }

    return $decoded;
}

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$path = is_string($path) ? rtrim($path, '/') : '';
$method = $_SERVER['REQUEST_METHOD'] ?? '';

if ($path === '/api/status' && $method === 'GET') {
    respond(200, ['ok' => true, 'status' => 'ok']);
}

if ($path === '/api/chat' && $method === 'POST') {
    $contentType = strtolower(trim(explode(';', $_SERVER['CONTENT_TYPE'] ?? '')[0]));
    if ($contentType !== 'application/json') {
        respond(415, ['ok' => false, 'error' => 'Content-Type debe ser application/json']);
    }

    $body = file_get_contents('php://input', false, null, 0, 1_048_577);
    if ($body === false || trim($body) === '') {
        respond(400, ['ok' => false, 'error' => 'El cuerpo de la solicitud está vacío']);
    }
    if (strlen($body) > 1_048_576) {
        respond(413, ['ok' => false, 'error' => 'El cuerpo supera el límite de 1 MB']);
    }

    try {
        $data = json_decode($body, true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException) {
        respond(400, ['ok' => false, 'error' => 'El cuerpo no contiene JSON válido']);
    }

    if (!is_array($data) || !isset($data['prompt']) || !is_string($data['prompt'])) {
        respond(400, ['ok' => false, 'error' => 'Se requiere un campo prompt de tipo texto']);
    }

    $prompt = trim($data['prompt']);
    if ($prompt === '') {
        respond(400, ['ok' => false, 'error' => 'El campo prompt no puede estar vacío']);
    }
    if (strlen($prompt) > 20_000) {
        respond(413, ['ok' => false, 'error' => 'El campo prompt supera el límite de 20000 bytes']);
    }

    $backend = getenv('AI_BACKEND') ?: 'ollama';
    $model = getenv('AI_MODEL') ?: ($backend === 'openai' ? 'gpt-4.1' : 'qwen2.5-coder:3b');
    if ($backend === 'ollama') {
        $apiBase = getenv('OLLAMA_API_BASE') ?: 'http://ollama:11434';
        $url = rtrim($apiBase, '/') . '/api/chat';
    } elseif ($backend === 'openai') {
        $apiBase = getenv('OPENAI_API_BASE') ?: 'https://api.openai.com/v1';
        $url = rtrim($apiBase, '/') . '/chat/completions';
    } else {
        error_log('Unsupported AI_BACKEND configuration');
        respond(503, ['ok' => false, 'error' => 'El backend de IA configurado no es compatible']);
    }

    $urlParts = parse_url($url);
    if (!is_array($urlParts) || !isset($urlParts['scheme'], $urlParts['host']) || !in_array($urlParts['scheme'], ['http', 'https'], true)) {
        error_log('Invalid AI API base URL configuration');
        respond(503, ['ok' => false, 'error' => 'La URL del proveedor de IA no está configurada correctamente']);
    }

    ini_set('max_execution_time', '250');
    $payload = [
        'model' => $model,
        'messages' => [
            ['role' => 'user', 'content' => $prompt],
        ],
    ];

    if ($backend === 'ollama') {
        $payload['stream'] = false;
        $aiResponse = requestAi($url, $payload);
        $answer = $aiResponse['message']['content'] ?? null;
    } else {
        $aiResponse = requestAi($url, $payload, getenv('OPENAI_API_KEY') ?: null);
        $answer = $aiResponse['choices'][0]['message']['content'] ?? null;
    }

    if (!is_string($answer)) {
        error_log('AI API response did not contain generated text');
        respond(502, ['ok' => false, 'error' => 'El proveedor de IA no devolvió texto']);
    }

    respond(200, ['ok' => true, 'model' => $model, 'response' => $answer]);
}

if ($path === '/api/status' || $path === '/api/chat') {
    header('Allow: ' . ($path === '/api/status' ? 'GET' : 'POST'));
    respond(405, ['ok' => false, 'error' => 'Método no permitido']);
}

respond(404, ['ok' => false, 'error' => 'Endpoint no encontrado']);
