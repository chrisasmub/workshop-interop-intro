import { CommonModule } from '@angular/common';
import { HttpErrorResponse, HttpResponse } from '@angular/common/http';
import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import {
  LoanApplicationResult,
  LoanCreditRatingResult,
  LoanPrimeRateResult,
  LoanRequestPayload,
  ProductionStatus,
  WorkshopService
} from '../workshop.service';

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
  prepare: boolean;
  prime: boolean;
  credit: boolean;
  application: boolean;
}

interface LoanPreset {
  id: string;
  title: string;
  hint: string;
  payload: LoanRequestPayload;
}

@Component({
  selector: 'app-loan-lab',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    MatButtonModule,
    MatCardModule,
    MatIconModule,
    MatProgressBarModule
  ],
  templateUrl: './loan-lab.component.html',
  styleUrl: './loan-lab.component.scss'
})
export class LoanLabComponent implements OnInit {
  readonly steps: StepDefinition[] = [
    {
      id: 'production',
      number: 1,
      title: 'Preparar Demo.Loan',
      description: 'Verifica que produccion esta activa y, si hace falta, detiene la actual para dejar lista Demo.Loan.FindRateProduction.'
    },
    {
      id: 'prime-rate',
      number: 2,
      title: 'Probar Prime Rate',
      description: 'Ejecuta la operacion simulada que alimenta a los bancos y confirma el valor base del ejemplo.'
    },
    {
      id: 'credit-rating',
      number: 3,
      title: 'Probar Credit Rating',
      description: 'Calcula el rating a partir del TaxID para anticipar que bancos podrian aprobar y con que tasa.'
    },
    {
      id: 'application',
      number: 4,
      title: 'Enviar solicitud completa',
      description: 'Corre el BPL real, espera la agregacion de respuestas y devuelve el resumen de la sesion en la misma pantalla.'
    }
  ];

  readonly presets: LoanPreset[] = [
    {
      id: 'strong-us',
      title: 'Caso solido USA',
      hint: 'Rating alto y nacionalidad USA para darle chances a BankUS.',
      payload: {
        amount: '18000',
        name: 'Paula Vega',
        taxId: '19',
        nationality: 'USA'
      }
    },
    {
      id: 'low-rating',
      title: 'Rating bajo',
      hint: 'Util para ver rechazos o tasas peores con un TaxID debil.',
      payload: {
        amount: '12000',
        name: 'Daniel Mora',
        taxId: '13',
        nationality: 'USA'
      }
    },
    {
      id: 'odd-name',
      title: 'Nombre impar',
      hint: 'Sirve para ver como BankEven cambia su aprobacion segun el largo del nombre.',
      payload: {
        amount: '14000',
        name: 'Nora',
        taxId: '17',
        nationality: 'Canada'
      }
    }
  ];

  readonly portalHome = 'http://localhost:52774/csp/sys/UtilHome.csp';
  readonly loading: LoadingState = {
    status: false,
    prepare: false,
    prime: false,
    credit: false,
    application: false
  };

  loanForm: LoanRequestPayload = { ...this.presets[0].payload };
  productionStatus: ProductionStatus | null = null;
  productionViewer: ActionResult | null = null;
  primeRateViewer: ActionResult | null = null;
  creditViewer: ActionResult | null = null;
  applicationViewer: ActionResult | null = null;
  primeRateResult: LoanPrimeRateResult | null = null;
  creditRatingResult: LoanCreditRatingResult | null = null;
  applicationResult: LoanApplicationResult | null = null;
  activityFeed: ActivityEntry[] = [];

  constructor(private workshopService: WorkshopService) {}

  ngOnInit(): void {
    this.checkProductionStatus();
  }

  checkProductionStatus(): void {
    this.loading.status = true;
    this.workshopService.getLoanProductionStatus().subscribe({
      next: (response) => {
        this.productionStatus = response.body ?? null;
        this.productionViewer = this.buildResult('Estado de Demo.Loan', response);
        this.appendActivity(
          'Estado consultado',
          this.productionStatus?.matchesRequestedProduction
            ? 'Demo.Loan ya esta lista para usarse.'
            : `La produccion activa actual es ${this.productionStatus?.runningProduction || 'ninguna'}.`,
          this.productionStatus?.matchesRequestedProduction ? 'success' : 'warning'
        );
      },
      error: (error) => {
        this.productionViewer = this.buildErrorResult('Estado de Demo.Loan', error);
        this.appendActivity('No se pudo consultar Loan', this.describeError(error), 'error');
      },
      complete: () => {
        this.loading.status = false;
      }
    });
  }

  prepareProduction(): void {
    this.loading.prepare = true;
    this.workshopService.prepareLoanProduction().subscribe({
      next: (response) => {
        this.productionStatus = response.body ?? null;
        this.productionViewer = this.buildResult('Preparacion de Demo.Loan', response);
        const action = response.body?.action ?? 'already-running';
        const detail = action === 'switched'
          ? `Se detuvo ${response.body?.previousProduction || 'otra produccion'} y se arranco Demo.Loan.FindRateProduction.`
          : action === 'started'
            ? 'Demo.Loan.FindRateProduction se arranco desde cero.'
            : 'Demo.Loan.FindRateProduction ya estaba lista.';
        this.appendActivity('Produccion preparada', detail, 'success');
      },
      error: (error) => {
        this.productionViewer = this.buildErrorResult('Preparacion de Demo.Loan', error);
        this.appendActivity('No se pudo preparar Loan', this.describeError(error), 'error');
      },
      complete: () => {
        this.loading.prepare = false;
      }
    });
  }

  runPrimeRate(): void {
    this.loading.prime = true;
    this.workshopService.testLoanPrimeRate().subscribe({
      next: (response) => {
        this.primeRateResult = response.body ?? null;
        this.primeRateViewer = this.buildResult('Prime Rate', response);
        this.productionStatus = response.body?.production ?? this.productionStatus;
        this.appendActivity(
          'Prime Rate listo',
          `La operacion devolvio ${response.body?.primeRate ?? 'sin dato'} como tasa base de la demo.`,
          'success'
        );
      },
      error: (error) => {
        this.primeRateViewer = this.buildErrorResult('Prime Rate', error);
        this.appendActivity('Fallo Prime Rate', this.describeError(error), 'error');
      },
      complete: () => {
        this.loading.prime = false;
      }
    });
  }

  runCreditRating(): void {
    this.loading.credit = true;
    this.workshopService.testLoanCreditRating(this.loanForm.taxId).subscribe({
      next: (response) => {
        this.creditRatingResult = response.body ?? null;
        this.creditViewer = this.buildResult('Credit Rating', response);
        this.productionStatus = response.body?.production ?? this.productionStatus;
        this.appendActivity(
          'Credit Rating calculado',
          `Con TaxID ${this.loanForm.taxId} el rating quedo en ${response.body?.creditRating ?? 'sin dato'}.`,
          'success'
        );
      },
      error: (error) => {
        this.creditViewer = this.buildErrorResult('Credit Rating', error);
        this.appendActivity('Fallo Credit Rating', this.describeError(error), 'error');
      },
      complete: () => {
        this.loading.credit = false;
      }
    });
  }

  runApplication(): void {
    this.loading.application = true;
    this.workshopService.submitLoanApplication(this.loanForm).subscribe({
      next: (response) => {
        this.applicationResult = response.body ?? null;
        this.applicationViewer = this.buildResult('Solicitud Loan', response);
        this.productionStatus = response.body?.production ?? this.productionStatus;
        const approval = response.body?.approval;
        const decision = approval?.isApproved
          ? `Aprobada por ${approval.bankName} con tasa ${approval.interestRate}%.`
          : `No aprobada. El mejor resultado vino de ${approval?.bankName || 'ningun banco'}.`;
        this.appendActivity('Solicitud ejecutada', decision, approval?.isApproved ? 'success' : 'warning');
      },
      error: (error) => {
        this.applicationViewer = this.buildErrorResult('Solicitud Loan', error);
        this.appendActivity('Fallo la solicitud Loan', this.describeError(error), 'error');
      },
      complete: () => {
        this.loading.application = false;
      }
    });
  }

  applyPreset(preset: LoanPreset): void {
    this.loanForm = { ...preset.payload };
    this.appendActivity('Preset cargado', `${preset.title}: ${preset.hint}`, 'neutral');
  }

  openPortal(url: string): void {
    window.open(url, '_blank', 'noopener');
  }

  asJson(value: unknown): string {
    return JSON.stringify(value, null, 2);
  }

  trackStep(_: number, step: StepDefinition): string {
    return step.id;
  }

  trackPreset(_: number, preset: LoanPreset): string {
    return preset.id;
  }

  buildResult<T>(title: string, response: HttpResponse<T>): ActionResult {
    return {
      title,
      status: response.status,
      ok: response.ok,
      body: response.body,
      at: new Date().toLocaleTimeString()
    };
  }

  buildErrorResult(title: string, error: HttpErrorResponse): ActionResult {
    return {
      title,
      status: error.status || 0,
      ok: false,
      body: error.error ?? { message: error.message },
      at: new Date().toLocaleTimeString()
    };
  }

  describeError(error: HttpErrorResponse): string {
    if (typeof error.error === 'string' && error.error.trim()) {
      return error.error;
    }

    if (error.error && typeof error.error === 'object') {
      return JSON.stringify(error.error);
    }

    return error.message;
  }

  appendActivity(title: string, detail: string, tone: ActivityEntry['tone']): void {
    this.activityFeed = [
      {
        title,
        detail,
        tone,
        at: new Date().toLocaleTimeString()
      },
      ...this.activityFeed
    ].slice(0, 12);
  }
}
