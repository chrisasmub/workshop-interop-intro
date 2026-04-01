import { CommonModule } from '@angular/common';
import { HttpErrorResponse, HttpResponse } from '@angular/common/http';
import { Component } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { NotificationEcho, OrderSummary, ProductionStatus, WorkshopService } from '../workshop.service';

interface StepDefinition {
  id: string;
  number: number;
  title: string;
  description: string;
}

interface ActionResult {
  title: string;
  status: number;
  ok: boolean;
  body: unknown;
  at: string;
}

interface ActivityEntry {
  title: string;
  detail: string;
  tone: 'success' | 'warning' | 'neutral' | 'error';
  at: string;
}

interface LoadingState {
  status: boolean;
  start: boolean;
  invalid: boolean;
  valid: boolean;
  orders: boolean;
  notification: boolean;
}

interface OrderPayload {
  OrderPriority: string;
  Discount: string;
  UnitPrice: string;
  ShippingCost: string;
  CustomerID: string;
  ShipMode: string;
  ProductCategory: string;
  ProductSubCategory: string;
  ProductContainer: string;
  ProductName: string;
  OrderDate: string;
  Quantity: string;
  Sales: string;
  OrderID: string;
}

@Component({
  selector: 'app-workshop-guide',
  standalone: true,
  imports: [
    CommonModule,
    MatButtonModule,
    MatCardModule,
    MatIconModule,
    MatProgressBarModule
  ],
  templateUrl: './workshop-guide.component.html',
  styleUrl: './workshop-guide.component.scss'
})
export class WorkshopGuideComponent {
  readonly steps: StepDefinition[] = [
    {
      id: 'production',
      number: 1,
      title: 'Preparar la producción',
      description: 'Comprueba el estado de Demo.Order.Production y arráncala desde la guía si todavía no está corriendo.'
    },
    {
      id: 'invalid-order',
      number: 2,
      title: 'Probar contrato inválido',
      description: 'Envía un POST vacío para mostrar el rechazo con 400 y el resumen de campos requeridos.'
    },
    {
      id: 'valid-order',
      number: 3,
      title: 'Enviar una orden válida',
      description: 'Dispara la orden de ejemplo para que entre al flujo y deje trazabilidad dentro de IRIS.'
    },
    {
      id: 'recent-orders',
      number: 4,
      title: 'Inspeccionar órdenes recientes',
      description: 'Recupera las últimas órdenes recibidas por la API para confirmar el paso anterior sin salir de la web.'
    },
    {
      id: 'portal',
      number: 5,
      title: 'Abrir visores de IRIS',
      description: 'Salta al portal, al Message Viewer y a la configuración de la producción para revisar la sesión en detalle.'
    }
  ];

  readonly portalLinks = {
    portalHome: 'http://localhost:52774/csp/sys/UtilHome.csp',
    productionConfig: 'http://localhost:52774/csp/interop/EnsPortal.ProductionConfig.zen',
    messageViewer: 'http://localhost:52774/csp/interop/EnsPortal.MessageViewer.zen'
  };

  readonly loading: LoadingState = {
    status: false,
    start: false,
    invalid: false,
    valid: false,
    orders: false,
    notification: false
  };

  readonly sampleOrderBase: Omit<OrderPayload, 'OrderID'> = {
    OrderPriority: 'High',
    Discount: '0.1',
    UnitPrice: '205.99',
    ShippingCost: '2.5',
    CustomerID: '3',
    ShipMode: 'Express Air',
    ProductCategory: 'Technology',
    ProductSubCategory: 'Telephones and Communication',
    ProductContainer: 'Small Box',
    ProductName: 'V70',
    OrderDate: '7/27/2011',
    Quantity: '8',
    Sales: '1446.67'
  };

  productionStatus: ProductionStatus | null = null;
  productionViewer: ActionResult | null = null;
  invalidResult: ActionResult | null = null;
  validResult: ActionResult | null = null;
  ordersResult: ActionResult | null = null;
  notificationViewer: ActionResult | null = null;
  notificationEcho: NotificationEcho | null = null;
  recentOrders: OrderSummary[] = [];
  activityFeed: ActivityEntry[] = [];
  latestSubmittedOrderId = '';
  lastValidPayload: OrderPayload | null = null;

  constructor(private workshopService: WorkshopService) {}

  checkProductionStatus(): void {
    this.loading.status = true;
    this.workshopService.getProductionStatus().subscribe({
      next: (response) => {
        this.productionStatus = response.body ?? null;
        this.productionViewer = this.buildResult('Estado de la producción', response);
        this.appendActivity(
          'Estado consultado',
          this.productionStatus?.isRunning
            ? `La producción activa es ${this.productionStatus.activeProduction}.`
            : 'No hay una producción corriendo en este momento.',
          this.productionStatus?.isRunning ? 'success' : 'warning'
        );
      },
      error: (error: HttpErrorResponse) => {
        this.productionViewer = this.buildErrorResult('Estado de la producción', error);
        this.appendActivity('Error al consultar estado', this.describeError(error), 'error');
      },
      complete: () => {
        this.loading.status = false;
      }
    });
  }

  startProduction(): void {
    this.loading.start = true;
    this.workshopService.startProduction().subscribe({
      next: (response) => {
        this.productionStatus = response.body ?? null;
        this.productionViewer = this.buildResult('Arranque de la producción', response);
        this.appendActivity(
          'Producción lista',
          `Demo.Order.Production quedó en estado ${this.productionStatus?.stateLabel ?? 'desconocido'}.`,
          'success'
        );
      },
      error: (error: HttpErrorResponse) => {
        this.productionViewer = this.buildErrorResult('Arranque de la producción', error);
        this.appendActivity('No se pudo arrancar la producción', this.describeError(error), 'error');
      },
      complete: () => {
        this.loading.start = false;
      }
    });
  }

  runInvalidOrderTest(): void {
    this.loading.invalid = true;
    this.workshopService.submitInvalidOrder().subscribe({
      next: (response) => {
        this.invalidResult = this.buildResult('POST inválido', response);
        this.appendActivity('Contrato inválido aceptado por error', 'El backend respondió sin rechazar el payload vacío.', 'warning');
      },
      error: (error: HttpErrorResponse) => {
        this.invalidResult = this.buildErrorResult('POST inválido', error);
        this.appendActivity(
          'Contrato inválido rechazado',
          `La API devolvió ${error.status} con el resumen esperado para el workshop.`,
          error.status === 400 ? 'success' : 'warning'
        );
      },
      complete: () => {
        this.loading.invalid = false;
      }
    });
  }

  runValidOrderTest(): void {
    const payload = this.buildValidOrderPayload();
    this.lastValidPayload = payload;
    this.notificationViewer = null;
    this.notificationEcho = null;
    this.loading.valid = true;

    this.workshopService.submitValidOrder(payload).subscribe({
      next: (response) => {
        this.validResult = this.buildResult('POST válido', response);
        this.appendActivity(
          'Orden enviada',
          `Se creó la orden ${payload.OrderID} para CustomerID ${payload.CustomerID}.`,
          'success'
        );
        this.loadRecentOrders();
      },
      error: (error: HttpErrorResponse) => {
        this.validResult = this.buildErrorResult('POST válido', error);
        this.appendActivity('Error al enviar orden válida', this.describeError(error), 'error');
        this.loading.valid = false;
      },
      complete: () => {
        this.loading.valid = false;
      }
    });
  }

  loadRecentOrders(): void {
    this.loading.orders = true;
    this.workshopService.getRecentOrders().subscribe({
      next: (response) => {
        this.recentOrders = response.body ?? [];
        this.ordersResult = this.buildResult('Órdenes recientes', response);

        const latest = this.recentOrders[0];
        this.appendActivity(
          'Listado actualizado',
          latest
            ? `La sesión más reciente es ${latest.sessionId} y corresponde a la orden ${latest.orderId}.`
            : 'La API devolvió una lista vacía de órdenes recientes.',
          latest ? 'success' : 'neutral'
        );

        if (latest) {
          this.loadNotificationEcho(latest.sessionId);
        }
      },
      error: (error: HttpErrorResponse) => {
        this.ordersResult = this.buildErrorResult('Órdenes recientes', error);
        this.appendActivity('Error al listar órdenes', this.describeError(error), 'error');
      },
      complete: () => {
        this.loading.orders = false;
      }
    });
  }

  loadNotificationEcho(sessionId: number, retriesLeft = 2): void {
    this.loading.notification = true;

    this.workshopService.getLatestNotificationEcho(sessionId).subscribe({
      next: (response) => {
        this.notificationEcho = response.body ?? null;
        this.notificationViewer = this.buildResult('Echo de Notification API Out', response);

        if (this.notificationEcho?.responseFound) {
          const origin = this.notificationEcho.httpbinOrigin ? ` desde ${this.notificationEcho.httpbinOrigin}` : '';
          this.appendActivity(
            'POST externo confirmado',
            `httpbin respondió para la sesión ${sessionId}${origin}.`,
            'success'
          );
        } else if (retriesLeft > 0) {
          window.setTimeout(() => this.loadNotificationEcho(sessionId, retriesLeft - 1), 1200);
        } else {
          this.appendActivity(
            'Echo pendiente',
            `La sesión ${sessionId} todavía no tiene una respuesta registrada de httpbin.`,
            'warning'
          );
        }
      },
      error: (error: HttpErrorResponse) => {
        this.notificationViewer = this.buildErrorResult('Echo de Notification API Out', error);
        this.appendActivity('Error al cargar el eco de httpbin', this.describeError(error), 'error');
      },
      complete: () => {
        this.loading.notification = false;
      }
    });
  }

  openPortal(url: string): void {
    window.open(url, '_blank', 'noopener');
  }

  get latestSessionId(): number | null {
    return this.recentOrders.length ? this.recentOrders[0].sessionId : null;
  }

  get latestVisualTraceLink(): string | null {
    return this.latestSessionId !== null
      ? `http://localhost:52774/csp/interop/EnsPortal.VisualTrace.zen?sessionId=${this.latestSessionId}`
      : null;
  }

  asJson(value: unknown): string {
    return JSON.stringify(value ?? {}, null, 2);
  }

  trackStep(_: number, step: StepDefinition): string {
    return step.id;
  }

  private buildValidOrderPayload(): OrderPayload {
    const orderId = String(Date.now()).slice(-6);
    this.latestSubmittedOrderId = orderId;

    return {
      ...this.sampleOrderBase,
      OrderID: orderId
    };
  }

  private buildResult(title: string, response: HttpResponse<unknown>): ActionResult {
    return {
      title,
      status: response.status,
      ok: response.ok,
      body: response.body,
      at: new Date().toLocaleTimeString()
    };
  }

  private buildErrorResult(title: string, error: HttpErrorResponse): ActionResult {
    return {
      title,
      status: error.status,
      ok: false,
      body: error.error ?? { message: error.message },
      at: new Date().toLocaleTimeString()
    };
  }

  private appendActivity(title: string, detail: string, tone: ActivityEntry['tone']): void {
    this.activityFeed = [
      {
        title,
        detail,
        tone,
        at: new Date().toLocaleTimeString()
      },
      ...this.activityFeed
    ].slice(0, 8);
  }

  private describeError(error: HttpErrorResponse): string {
    if (error.error?.summary) {
      return error.error.summary;
    }

    if (typeof error.error === 'string' && error.error.trim() !== '') {
      return error.error;
    }

    return error.message;
  }
}
