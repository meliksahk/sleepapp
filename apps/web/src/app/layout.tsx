import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'NOCTA — Your night has an identity',
  description: 'A sleep ritual app built around sleep identity.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
