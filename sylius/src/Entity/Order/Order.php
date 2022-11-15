<?php

declare(strict_types=1);

namespace App\Entity\Order;

use BitBag\SyliusMolliePlugin\Entity\AbandonedEmailOrderTrait;
use BitBag\SyliusMolliePlugin\Entity\OrderInterface as MollieOrderInterface;
use BitBag\SyliusMolliePlugin\Entity\ProductVariantInterface;
use BitBag\SyliusMolliePlugin\Entity\RecurringOrderTrait;
use Doctrine\Common\Collections\Collection;
use Doctrine\ORM\Mapping as ORM;
use Sylius\Component\Core\Model\Order as BaseOrder;
use Sylius\Component\Core\Model\OrderInterface;
use Sylius\Component\Core\Model\OrderItemInterface;
use Sylius\Plus\Returns\Domain\Model\OrderInterface as ReturnsOrderInterface;
use Sylius\Plus\Returns\Domain\Model\ReturnRequestAwareTrait;

/**
 * @ORM\Entity
 * @ORM\Table(name="sylius_order")
 */
class Order extends BaseOrder implements OrderInterface, ReturnsOrderInterface, MollieOrderInterface
{
    use ReturnRequestAwareTrait;
    use AbandonedEmailOrderTrait;
    use RecurringOrderTrait;

    /**
     * @var bool
     * @ORM\Column(type="boolean", name="abandoned_email")
     */
    protected $abandonedEmail = false;

    public function getRecurringItems(): Collection
    {
        return $this->items // @phpstan-ignore-line
            ->filter(function (OrderItemInterface $orderItem) { // @phpstan-ignore-line
                $variant = $orderItem->getVariant();

                return $variant instanceof ProductVariantInterface &&
                    true === $variant->isRecurring();
            })
        ;
    }

    public function getNonRecurringItems(): Collection
    {
        return $this->items // @phpstan-ignore-line
            ->filter(function (OrderItemInterface $orderItem) { //@phpstan-ignore-line
                $variant = $orderItem->getVariant();

                return $variant instanceof ProductVariantInterface &&
                    false === $variant->isRecurring();
            })
        ;
    }

    public function hasRecurringContents(): bool
    {
        return 0 < $this->getRecurringItems()->count();
    }

    public function hasNonRecurringContents(): bool
    {
        return 0 < $this->getNonRecurringItems()->count();
    }
}
