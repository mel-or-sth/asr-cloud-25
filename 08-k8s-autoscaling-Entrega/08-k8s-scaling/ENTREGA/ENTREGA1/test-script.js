import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 5,        // Número de usuarios virtuales
  duration: '20s', // Duración de la prueba
};

export default function () {
  const res = http.get('https://test.k6.io');
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}