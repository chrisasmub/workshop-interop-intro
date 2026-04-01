import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { OrderCreateComponent } from './order-create/order-create.component';
import { authGuard } from '../auth.guard';
import { WorkshopGuideComponent } from './workshop-guide/workshop-guide.component';

export const routes: Routes = [
  {
    path: '',
    component: WorkshopGuideComponent,
    canActivate: [authGuard]
  },
  {
    path: 'guide',
    component: WorkshopGuideComponent,
    canActivate: [authGuard]
  },
  {
    path: 'create-order',
    component: OrderCreateComponent,
    canActivate: [authGuard]
  }
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule]
})
export class DemoRoutingModule { }
