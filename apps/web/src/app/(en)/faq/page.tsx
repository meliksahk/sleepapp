import type { Metadata } from 'next';
import { FaqView } from '@/components/FaqView';
import { buildFaqMetadata } from '@/lib/page-metadata';

export const metadata: Metadata = buildFaqMetadata('en');

export default function FaqPage() {
  return <FaqView locale="en" />;
}
