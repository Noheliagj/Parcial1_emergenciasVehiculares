import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';


@Component({
  selector: 'app-root',
  standalone: true,
  // Aquí solo necesitamos RouterOutlet para que funcionen las rutas
  imports: [RouterOutlet], 
  templateUrl: './app.html',
  styleUrls: ['./app.scss']
})
export class App { 
  title = 'frontend-web';
}