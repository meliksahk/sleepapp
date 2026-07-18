import type { Metadata } from 'next';
import { HomeView } from '@/components/HomeView';
import { buildHomeMetadata } from '@/lib/page-metadata';

export const metadata: Metadata = buildHomeMetadata('en');

export default function HomePage() {
  return <HomeView locale="en" />;
}
