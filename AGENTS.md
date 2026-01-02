# Web Development Project Guidelines

## AI Assistant Rules

> **Read this section first.** These are hard constraints for code generation.

### MUST

- Use TypeScript with strict mode for all new code
- Use `async/await` for all asynchronous code - never callbacks
- Use Vitest for all tests with `describe`, `it`, `expect` patterns
- Write tests FIRST before implementation (TDD)
- Use ESLint and Prettier for code quality
- Use environment variables for all configuration (never hardcode secrets)
- Use explicit return types for public functions
- Use `const` by default, `let` only when mutation is required
- Implement proper error handling with typed errors
- Follow the repository pattern for data access
- Use dependency injection for testability

### NEVER

- Use `any` type without explicit justification
- Use `var` - always use `const` or `let`
- Store secrets in code or version control
- Use synchronous file/network operations in async contexts
- Disable TypeScript strict checks
- Skip error handling for async operations
- Use mutable global state
- Commit `.env` files or credentials
- Write implementation code without corresponding tests

### PREFER

- Functional programming patterns over imperative
- Composition over inheritance
- Small, focused functions (< 30 lines)
- Early returns with guard clauses
- Template literals over string concatenation
- Optional chaining (`?.`) and nullish coalescing (`??`)
- Named exports over default exports
- Descriptive variable names over comments
- Red-Green-Refactor TDD cycle

---

## Tech Stack

| Layer           | Technology      | Notes                 |
| --------------- | --------------- | --------------------- |
| Language        | TypeScript 5.7+ | Strict mode, ESM      |
| Runtime         | Node.js 24+     | LTS, native ESM       |
| Testing         | Vitest          | Fast, Vite-compatible |
| Linting         | ESLint 9        | Flat config           |
| Formatting      | Prettier 3      | Consistent style      |
| Package Manager | npm             | Or pnpm/yarn          |
| CI/CD           | GitHub Actions  | Lint, test, deploy    |

---

## Test-Driven Development (TDD)

### The TDD Cycle

1. **RED**: Write a failing test that defines the expected behavior
2. **GREEN**: Write minimal code to make the test pass
3. **REFACTOR**: Improve the code while keeping tests green

### TDD Workflow Example

```typescript
// Step 1: RED - Write the failing test first
import { describe, it, expect } from 'vitest';
import { ItemService } from './item.service';

describe('ItemService', () => {
  it('should create an item with valid input', async () => {
    const service = new ItemService(new InMemoryRepository());

    const result = await service.create({ title: 'Test Item' });

    expect(result.title).toBe('Test Item');
    expect(result.id).toBeDefined();
  });
});

// Step 2: GREEN - Implement minimal code to pass
export class ItemService {
  constructor(private readonly repository: ItemRepository) {}

  async create(input: CreateItemInput): Promise<Item> {
    return this.repository.create(input);
  }
}

// Step 3: REFACTOR - Add validation, error handling
async create(input: CreateItemInput): Promise<Item> {
  if (!input.title.trim()) {
    throw new ValidationError('Title is required');
  }
  return this.repository.create(input);
}
```

### Test Structure

```typescript
describe('FeatureName', () => {
  // Setup
  let service: Service;
  let mockRepository: MockRepository;

  beforeEach(() => {
    mockRepository = new MockRepository();
    service = new Service(mockRepository);
  });

  // Group related tests
  describe('methodName', () => {
    it('should do X when Y', async () => {
      // Arrange
      const input = { ... };

      // Act
      const result = await service.methodName(input);

      // Assert
      expect(result).toEqual(expected);
    });

    it('should throw error when invalid', async () => {
      await expect(service.methodName(invalid))
        .rejects.toThrow('Expected error');
    });
  });
});
```

---

## Architecture

### Project Structure

```text
project/
├── src/
│   ├── api/              # API route handlers
│   │   └── routes/       # Route definitions
│   ├── services/         # Business logic
│   ├── repositories/     # Data access layer
│   ├── models/           # Type definitions
│   ├── lib/              # Shared utilities
│   └── index.ts          # Entry point
├── tests/
│   ├── unit/             # Unit tests
│   ├── integration/      # Integration tests
│   └── e2e/              # End-to-end tests
├── package.json
├── tsconfig.json
├── vitest.config.ts
└── eslint.config.js
```

### Service Layer Pattern

```typescript
// services/item.service.ts
import type { ItemRepository } from '@/repositories/item.repository';
import type { Item, CreateItemInput } from '@/models/item';

export class ItemService {
  constructor(private readonly repository: ItemRepository) {}

  async findAll(): Promise<Item[]> {
    return this.repository.findAll();
  }

  async create(input: CreateItemInput): Promise<Item> {
    if (!input.title.trim()) {
      throw new ValidationError('Title is required');
    }
    return this.repository.create(input);
  }

  async delete(id: string): Promise<void> {
    const exists = await this.repository.exists(id);
    if (!exists) {
      throw new NotFoundError(`Item ${id} not found`);
    }
    return this.repository.delete(id);
  }
}
```

### Repository Pattern

```typescript
// repositories/item.repository.ts
export interface ItemRepository {
  findAll(): Promise<Item[]>;
  findById(id: string): Promise<Item | null>;
  create(input: CreateItemInput): Promise<Item>;
  update(id: string, input: UpdateItemInput): Promise<Item>;
  delete(id: string): Promise<void>;
  exists(id: string): Promise<boolean>;
}

// In-memory implementation for testing
export class InMemoryItemRepository implements ItemRepository {
  private items: Map<string, Item> = new Map();

  async findAll(): Promise<Item[]> {
    return Array.from(this.items.values());
  }

  async create(input: CreateItemInput): Promise<Item> {
    const item: Item = {
      id: crypto.randomUUID(),
      ...input,
      createdAt: new Date(),
    };
    this.items.set(item.id, item);
    return item;
  }
}
```

---

## Testing with Vitest

```typescript
// tests/unit/services/item.service.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { ItemService } from '@/services/item.service';
import { InMemoryItemRepository } from '@/repositories/item.repository';

describe('ItemService', () => {
  let service: ItemService;
  let repository: InMemoryItemRepository;

  beforeEach(() => {
    repository = new InMemoryItemRepository();
    service = new ItemService(repository);
  });

  describe('create', () => {
    it('should create an item with valid input', async () => {
      const result = await service.create({ title: 'Test Item' });

      expect(result).toMatchObject({
        title: 'Test Item',
      });
      expect(result.id).toBeDefined();
    });

    it('should throw ValidationError for empty title', async () => {
      await expect(service.create({ title: '  ' })).rejects.toThrow('Title is required');
    });
  });

  describe('delete', () => {
    it('should throw NotFoundError for non-existent item', async () => {
      await expect(service.delete('non-existent')).rejects.toThrow('Item non-existent not found');
    });
  });
});
```

---

## API Routes Pattern

```typescript
// api/routes/items.ts
import type { Request, Response, NextFunction } from 'express';

export async function getItems(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const items = await itemService.findAll();
    res.json({ data: items });
  } catch (error) {
    next(error);
  }
}

export async function createItem(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const item = await itemService.create(req.body);
    res.status(201).json({ data: item });
  } catch (error) {
    next(error);
  }
}
```

---

## Environment Configuration

```typescript
// lib/config.ts
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.string().transform(Number).default('3000'),
  DATABASE_URL: z.string().url(),
  API_KEY: z.string().min(1),
});

export type Env = z.infer<typeof envSchema>;

export function loadConfig(): Env {
  const result = envSchema.safeParse(process.env);

  if (!result.success) {
    console.error('Invalid environment variables:', result.error.format());
    process.exit(1);
  }

  return result.data;
}

export const config = loadConfig();
```

---

## Error Handling

```typescript
// lib/errors.ts
export class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number = 500
  ) {
    super(message);
    this.name = this.constructor.name;
  }
}

export class ValidationError extends AppError {
  constructor(message: string) {
    super(message, 'VALIDATION_ERROR', 400);
  }
}

export class NotFoundError extends AppError {
  constructor(message: string) {
    super(message, 'NOT_FOUND', 404);
  }
}

// Async utility
export async function tryCatch<T>(promise: Promise<T>): Promise<[T, null] | [null, Error]> {
  try {
    return [await promise, null];
  } catch (error) {
    return [null, error instanceof Error ? error : new Error(String(error))];
  }
}
```

---

## GitHub Actions CI

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Type check
        run: npm run typecheck

      - name: Lint
        run: npm run lint

      - name: Format check
        run: npm run format:check

      - name: Test
        run: npm run test:coverage

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-report
          path: coverage/
```

---

## Naming Conventions

| Type             | Convention      | Example           |
| ---------------- | --------------- | ----------------- |
| Files            | kebab-case      | `item.service.ts` |
| Classes          | PascalCase      | `ItemService`     |
| Functions        | camelCase       | `findById`        |
| Constants        | SCREAMING_SNAKE | `MAX_RETRY_COUNT` |
| Types/Interfaces | PascalCase      | `CreateItemInput` |
| Enums            | PascalCase      | `ItemStatus`      |

---

## Quick Commands

```bash
# Development
npm run dev          # Start development server
npm run build        # Build for production
npm run typecheck    # Check types

# Quality
npm run lint         # Run ESLint
npm run lint:fix     # Fix lint issues
npm run format       # Format with Prettier
npm run format:check # Check formatting

# Testing
npm run test         # Run tests
npm run test:watch   # Watch mode
npm run test:coverage # With coverage
```
