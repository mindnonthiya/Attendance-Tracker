# AliveBooks

AliveBooks is a full-stack bookstore management project with a React + Vite frontend and a NestJS + MySQL backend. The app lets users browse books, add items to a cart, mark favorites, review an order summary, and manage the book catalog through create, update, and delete actions.

## Overview

This repository contains two applications:

- **Frontend (`/`)** — A React application that uses Redux Toolkit for state management and React Router for page navigation.
- **Backend (`/bookstore-backend`)** — A NestJS REST API connected to MySQL through TypeORM.

The frontend calls the backend at `http://localhost:3000/books`, while the backend enables CORS for the Vite development server at `http://localhost:5173`.

## Key Features

### Storefront experience
- Browse the available book collection.
- Add books to a shopping cart.
- Mark and review favorite books.
- View an order summary with item quantities and total price.

### Admin / catalog management
- Create new books.
- Edit existing books.
- Delete books from the catalog.
- Preview a cover image before saving a book.

### Backend API
- REST endpoints for listing, creating, updating, retrieving, and deleting books.
- MySQL persistence through TypeORM.
- Validation pipeline enabled globally in NestJS.

## Tech Stack

### Frontend
- React 19
- TypeScript
- Vite
- Redux Toolkit
- React Redux
- React Router DOM
- Axios

### Backend
- NestJS
- TypeScript
- TypeORM
- MySQL
- class-validator / class-transformer

## Project Structure

```text
AliveBooks/
├── src/                     # Frontend source code
│   ├── components/          # Pages and UI components
│   └── store/               # Redux store and book slice
├── bookstore-backend/       # NestJS backend application
│   ├── src/
│   │   ├── books/           # Book entity, controller, service, module
│   │   └── main.ts          # App bootstrap and CORS setup
│   └── test/                # E2E test config
├── package.json             # Frontend scripts and dependencies
└── README.md                # Project documentation
```

## Application Flow

1. The React frontend loads book data using Redux async thunks.
2. Axios sends requests to the backend endpoint: `http://localhost:3000/books`.
3. The NestJS backend processes requests through the `BooksController` and `BooksService`.
4. TypeORM reads and writes book records in the MySQL database.
5. The Redux store keeps local UI state for books, favorites, and cart items.

## Prerequisites

Before running the project, make sure you have:

- **Node.js** 18+ recommended
- **npm**
- **MySQL** running locally or remotely

## Getting Started

### 1) Install frontend dependencies

From the repository root:

```bash
npm install
```

### 2) Install backend dependencies

```bash
cd bookstore-backend
npm install
```

### 3) Create the database

Create a MySQL database named `bookstore` or use your own name and update the backend environment variables.

Example:

```sql
CREATE DATABASE bookstore;
```

### 4) Configure backend environment variables

Create a `.env` file inside `bookstore-backend/`.

Example:

```env
PORT=3000
DB_HOST=localhost
DB_PORT=3306
DB_USERNAME=root
DB_PASSWORD=12345678
DB_NAME=bookstore
```

> Note: The backend currently falls back to these same default values if environment variables are not set.

### 5) Make sure the `books` table exists

The backend uses a `Book` entity with the following fields:

- `id` (primary key)
- `bookname`
- `ISBN`
- `price`
- `image_url`

Because the backend is configured with `synchronize: false`, TypeORM will **not** create the table automatically. You should create the table yourself or add your own migration workflow.

Example SQL:

```sql
CREATE TABLE book (
  id INT NOT NULL AUTO_INCREMENT,
  bookname VARCHAR(120) NOT NULL,
  ISBN VARCHAR(20) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  image_url VARCHAR(255) NULL,
  PRIMARY KEY (id)
);
```

> Depending on your TypeORM naming strategy, verify whether your environment expects `book` or `books` as the physical table name.

## Running the Project

You should run the frontend and backend in separate terminals.

### Start the backend

```bash
cd bookstore-backend
npm run start:dev
```

Backend URL:

```text
http://localhost:3000
```

### Start the frontend

From the repository root:

```bash
npm run dev
```

Frontend URL:

```text
http://localhost:5173
```

## Available Scripts

### Frontend scripts

From the repository root:

```bash
npm run dev
npm run build
npm run lint
npm run preview
```

### Backend scripts

From `bookstore-backend/`:

```bash
npm run start
npm run start:dev
npm run start:prod
npm run build
npm run lint
npm run test
npm run test:e2e
npm run test:cov
```

## Frontend Pages

- **Home (`/`)**
  - Loads all books from the backend
  - Supports cart and favorites popups
  - Allows adding books to the cart
- **Orders (`/orders`)**
  - Displays items currently in the cart
  - Supports quantity increments and item removal
- **Manage Books (`/books/list`)**
  - Lists all books for editing and deletion
  - Opens the edit form inline
- **Add Book (`/books/new`)**
  - Creates a new book record
  - Supports image URL preview

## API Reference

Base URL:

```text
http://localhost:3000/books
```

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/books` | Get all books |
| GET | `/books/:id` | Get one book by ID |
| POST | `/books` | Create a new book |
| PUT | `/books/:id` | Update a book |
| DELETE | `/books/:id` | Delete a book |

### Example request body

```json
{
  "bookname": "The Pragmatic Programmer",
  "ISBN": "9780135957059",
  "price": 42.5,
  "image_url": "https://example.com/book-cover.jpg"
}
```

## Current Data Model

```ts
interface Book {
  id: number;
  bookname: string;
  ISBN: string;
  price: number;
  image_url?: string;
}
```

Cart items extend the same book model with a `quantity` field on the frontend.

## Notes and Limitations

- The cart and favorites are stored in Redux state only, so they reset when the page reloads.
- The frontend expects the backend API to be available at `http://localhost:3000`.
- The backend CORS configuration currently allows `http://localhost:5173`.
- The backend does not currently include migrations in this repository.
- The backend README inside `bookstore-backend/` is still the default NestJS starter documentation.

## Suggested Next Improvements

- Add database migrations.
- Persist cart and favorites to local storage or a backend service.
- Add form validation messages on the frontend.
- Add authentication for admin actions.
- Add automated integration tests for the full create/edit/delete flow.
- Add seed data for easier local setup.

## Troubleshooting

### Frontend loads but no books appear
- Confirm the backend is running on port `3000`.
- Confirm the database connection succeeds.
- Check the browser console and backend terminal logs.

### Backend starts but book requests fail
- Verify the MySQL credentials in `bookstore-backend/.env`.
- Confirm the database exists.
- Confirm the books table has been created.

### CORS errors in the browser
- Make sure the frontend is running on `http://localhost:5173`.
- If you changed the frontend port, update the backend CORS configuration in `bookstore-backend/src/main.ts`.

## License

This repository does not currently define a top-level project license. The backend package is marked as `UNLICENSED` in its package metadata.
