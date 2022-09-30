<?php

declare(strict_types=1);

namespace App\EventListener;

use Psr\Log\LoggerInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\ExceptionEvent;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Symfony\Component\HttpKernel\Exception\MethodNotAllowedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Throwable;

final class KernelExceptionListener
{
    public function __construct(
        private LoggerInterface $logger,
        private string $environment,
    ) {
    }

    public function onKernelException(ExceptionEvent $event): void
    {
        if (!$event->isMainRequest()) {
            return;
        }
        $request = $event->getRequest();

        if ($request->attributes->get('_route') === '_wdt') {
            return;
        }

        if ($this->environment === 'dev') {
            return;
        }

        $exception = $event->getThrowable();

        $event->setResponse($this->createResponse($exception));
    }

    private function createResponse(Throwable $exception): Response
    {
        if ($exception instanceof MethodNotAllowedHttpException) {
            return new JsonResponse(
                ['error' => 'Method not allowed'],
                Response::HTTP_METHOD_NOT_ALLOWED,
            );
        }

        if ($exception instanceof NotFoundHttpException) {
            return new JsonResponse(
                ['error' => 'Route not found.'],
                Response::HTTP_NOT_FOUND,
            );
        }

        if ($exception instanceof HttpException) {
            return new JsonResponse(
                ['error' => $exception->getMessage()],
                $exception->getStatusCode(),
            );
        }

        $this->logger->error($exception->getMessage(), ['exception' => $exception]);

        return new JsonResponse(
            ['error' => 'Internal server error.'],
            Response::HTTP_INTERNAL_SERVER_ERROR,
        );
    }
}
