<?php
// Service PHP minimal : une route, servie par Slim, instrumentee par l'auto-instrumentation.
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Slim\Factory\AppFactory;

require __DIR__ . '/../vendor/autoload.php';

$app = AppFactory::create();

$app->get('/ship', function (Request $request, Response $response) {
    $response->getBody()->write(json_encode([
        'carrier' => 'colissimo',
        'eta_days' => 2,
    ]));
    return $response->withHeader('Content-Type', 'application/json');
});

$app->run();
