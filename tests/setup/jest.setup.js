// Jest Setup for Dental System Testing
import '@testing-library/jest-dom';

// Mock Rails CSRF token
global.document.querySelector = jest.fn((selector) => {
  if (selector === 'meta[name="csrf-token"]') {
    return { getAttribute: () => 'mock-csrf-token' };
  }
  return null;
});

// Mock fetch for API calls
global.fetch = jest.fn();

// Mock console methods for cleaner test output
global.console = {
  ...console,
  warn: jest.fn(),
  error: jest.fn(),
};

// Mock window.location
Object.defineProperty(window, 'location', {
  value: {
    href: 'http://localhost:3000',
    assign: jest.fn(),
    reload: jest.fn(),
  },
  writable: true,
});

// Mock Rails UJS
global.Rails = {
  fire: jest.fn(),
  ajax: jest.fn(),
};

// Clean up after each test
afterEach(() => {
  jest.clearAllMocks();
  fetch.mockClear();
});

// Setup global test timeout
jest.setTimeout(10000);

// Mock bootstrap components if used
global.bootstrap = {
  Modal: jest.fn().mockImplementation(() => ({
    show: jest.fn(),
    hide: jest.fn(),
  })),
  Toast: jest.fn().mockImplementation(() => ({
    show: jest.fn(),
    hide: jest.fn(),
  })),
};