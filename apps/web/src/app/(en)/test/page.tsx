import type { Metadata } from 'next';
import { TestView } from '@/components/TestView';
import { buildTestMetadata } from '@/lib/page-metadata';

export const metadata: Metadata = buildTestMetadata('en');

export default function TestPage() {
  return <TestView locale="en" />;
}
