# EPUB Reader Design

Date: 2026-04-22
Project: Gravity Reader
Status: Draft for review

## 1. Goal

Add real EPUB reading support with long-term architecture value.

This design explicitly does not flatten EPUB into TXT. The system should parse EPUB structure and content into an internal document model, then paginate that model into the existing one-screen-per-page reading experience.

The target is:

- Preserve more than plain text: headings, paragraphs, bold, italic, quotes, separators, and images.
- Keep the app's existing reader shell consistent with TXT reading: background, controls, progress UI, theme entry points, toolbar behavior.
- Build a foundation that can later support search, annotations, TTS alignment, richer styling, and broader EPUB compatibility.

## 2. Confirmed Scope

### In Scope for Phase 1

- Parse mainstream reflowable EPUB files.
- Render EPUB content as one-screen-per-page horizontal pagination.
- Preserve these content elements:
  - Headings
  - Paragraphs
  - Bold and italic inline styles
  - Quotes
  - Separators
  - Images
- Support TOC-based chapter navigation.
- Support reader progress restore using a structural locator, not page number.
- Reuse the existing reader shell and theme controls as much as possible.

### Explicitly Out of Scope for Phase 1

- Fixed-layout EPUB
- Ruby
- Vertical writing
- Footnote popup systems
- Tables with high-fidelity layout
- Full browser-grade CSS compatibility
- Scripted EPUB behavior
- Guaranteeing identical visual output to every original EPUB reader

## 3. Product Principles

### 3.1 Long-Term Direction

EPUB support must be built as an independent reading content engine, not as a TXT extension. TXT and EPUB may share the same reader shell, but they should not share the same content layout assumptions.

### 3.2 Reader Consistency

The reader should feel like one app, not two separate products. The following should remain consistent across TXT and EPUB:

- Background mode and background color behavior
- Top and bottom controls
- Progress UI
- Theme and typography entry points
- Page-turn interaction
- Reader chrome and immersion model

### 3.3 Content Fidelity Boundary

The app should preserve EPUB semantic structure and major rich-text styling, but not chase perfect source fidelity in phase 1. When EPUB source styles conflict with app readability and stability, the system should prefer readable normalized output.

## 4. Architecture

The implementation is split into four layers.

### 4.1 EPUB Package Parsing Layer

Responsibility:

- Read `.epub` as an archive
- Parse `container.xml`
- Parse OPF metadata, manifest, spine
- Parse navigation from EPUB nav or NCX
- Resolve resource paths
- Load chapter XHTML source
- Build resource indexes for images, cover, fonts, and stylesheets

Output:

- `EpubPackage`

Suggested structure:

- `metadata`
- `manifestItems`
- `spineItems`
- `toc`
- `resources`

This replaces the current stub-only flow in `lib/flureadium_integration/epub_parser.dart`.

### 4.2 Internal Document Model Layer

This layer converts chapter XHTML into a normalized internal reader document model.

Core entities:

- `BookDocument`
- `ChapterDocument`
- `BlockNode`
- `InlineNode`
- `ReaderLocator`

Phase 1 block nodes:

- Heading block
- Paragraph block
- Quote block
- Separator block
- Image block

Phase 1 inline nodes:

- Text
- Bold
- Italic
- Link
- Styled span

Every node should preserve source mapping metadata, at minimum:

- `spineIndex`
- `chapterHref`
- `blockIndex`
- `inlineOffset`
- `nodePath` when the parser can produce a stable ancestry path for the node

This layer is the main long-term asset. Search, annotations, TTS alignment, and richer rendering should all build on this model.

### 4.3 Pagination and Layout Layer

This layer receives `ChapterDocument` plus current reader configuration and produces paginated pages.

Inputs:

- Chapter document
- Viewport size
- Font size
- Line height
- Reader padding
- Theme profile
- Image display policy

Outputs:

- `PaginatedChapter`
- `PageLayout`
- `PageSegment`

The paginator must paginate the layout result, not raw text length.

### 4.4 Reader Adapter Layer

`ReaderPage` should remain the reader shell, while content loading and page building move behind a reader engine abstraction.

Suggested interface:

- `loadBook()`
- `buildPage(index)`
- `jumpToLocator()`
- `jumpToTocEntry()`
- `serializeLocation()`
- `deserializeLocation()`
- `resolveProgress()`

Implementations:

- `TxtReaderEngine`
- `EpubReaderEngine`

This avoids growing `lib/presentation/pages/reader/reader_page.dart` further.

## 5. Data Flow and Caching

### 5.1 Import-Time Structural Cache

When importing an EPUB from the bookshelf flow, perform structural parsing and cache the parsed publication data.

Cache contents:

- Metadata
- Manifest, spine, TOC
- Normalized chapter documents
- Resource index
- Chapter statistics

Do not precompute final pagination during import. Pagination depends on runtime variables such as screen size, font size, line height, padding, and image constraints.

### 5.2 Open-Time Loading

When opening a book:

1. Load structural cache
2. Restore saved `ReaderLocator`
3. Paginate current chapter and nearby chapters on demand
4. Build the initial page window

### 5.3 Pagination Cache

Pagination results should be cached separately from structure.

Suggested cache key fields:

- `bookId`
- `spineIndex`
- `viewportWidth`
- `viewportHeight`
- `fontSize`
- `lineHeight`
- `paddingPreset`
- `imageLayoutPolicy`
- `themeProfileVersion`

If any of these values change, that chapter pagination cache becomes invalid.

### 5.4 Runtime State Split

Long-lived state:

- `EpubPackage`
- `BookDocument`
- `ChapterDocument`
- Resource index

Short-lived state:

- Current page window
- Current locator
- Current visible page index
- Background pre-pagination jobs

This split prevents `ReaderPage` from holding too many book-format-specific state variables.

### 5.5 Resource Handling

Image handling should not decode raw large assets during pagination without metadata.

On import or first load, establish:

- resource file mapping
- image dimensions
- image metadata cache

Phase 1 only requires original resource mapping plus trustworthy image dimensions. Derived scaled variants are deferred unless profiling proves they are necessary.

Pagination should operate on known image dimensions and display constraints.

## 6. Pagination Model

### 6.1 Layout Unit

Pagination should operate on a flow of layoutable blocks.

The engine should:

1. Lay out blocks in order
2. Lay out inline content within each block
3. Decide whether to keep a block whole or split it across pages

### 6.2 Phase 1 Page-Break Rules

- Heading blocks should not split across pages.
- Short paragraphs should prefer staying whole.
- Long paragraphs may split by line.
- Quote blocks may split, while preserving quote styling on continued pages.
- Separator blocks should not split.
- Image blocks should not split.
- Oversized images should first scale to the viewport.
- If an image is still too tall after scaling constraints, it becomes a dedicated image page.
- Phase 1 will not crop one image across multiple pages.

### 6.3 Page Result Model

Each page should contain structured segments that point back to source document ranges.

Suggested page result data:

- `pageIndex`
- `chapterIndex`
- `segments`

Each segment should track:

- `blockIndex`
- `startInlineOffset`
- `endInlineOffset`
- `segmentType`
- `paintBounds`

This supports location restore, search mapping, and future TTS or annotation alignment.

## 7. Locator and Progress System

### 7.1 Locator Format

EPUB progress must not be stored as only page number.

Primary progress should use `ReaderLocator` with at least:

- `spineIndex`
- `blockIndex`
- `inlineOffset`
- `bias`

Optional future resilience fields:

- `textContextBefore`
- `textContextAfter`

### 7.2 Restore Strategy

When restoring progress:

1. Load structure cache
2. Load the target chapter
3. Paginate with current settings
4. Map locator to the nearest page
5. Open that page

### 7.3 Style Change Reflow

When font size, line height, or padding changes:

1. Keep the existing locator
2. Invalidate affected pagination cache
3. Re-paginate the current chapter window
4. Map the old locator into the new layout
5. Keep the user near the same sentence or content position

Displayed percentage can still be saved for UI, but true restore should always use locator.

## 8. Styling Strategy

### 8.1 Style Ownership

The final reading style is a composition of:

- App-controlled reader shell defaults
- EPUB semantic defaults
- Explicit EPUB inline or block style signals
- Safety normalization

### 8.2 App-Controlled Reader Shell

The app should own:

- Background and background modes
- Reader chrome
- Toolbar surfaces
- Progress panel and theme controls
- Reader padding baseline
- Global theme palette
- Highlight colors

### 8.3 EPUB-Preserved Rich Content

Phase 1 should preserve:

- Heading hierarchy
- Paragraph structure
- Bold and italic
- Quote presentation
- Separators
- Images
- Basic alignment
- Basic indentation

Phase 1 should not promise:

- complex CSS selectors
- floats
- tables
- ruby
- vertical layout
- fixed-layout support

### 8.4 Safety Normalization

The style resolver must normalize extreme or unsafe styles.

Examples:

- Clamp too-small font sizes
- Prevent unreadable low-contrast text in dark mode
- Constrain image size to page bounds
- Clamp extreme margins and padding

## 9. Codebase Integration Plan

### 9.1 New Parsing Modules

Create `lib/data/services/epub/` with at least:

- `epub_archive_service.dart`
- `opf_parser.dart`
- `nav_parser.dart`
- `xhtml_document_parser.dart`
- `epub_import_cache_service.dart`

### 9.2 New Domain Model Modules

Create `lib/domain/entities/reader_document/` with:

- `book_document.dart`
- `chapter_document.dart`
- `block_node.dart`
- `inline_node.dart`
- `reader_locator.dart`

### 9.3 New Pagination Modules

Create `lib/data/services/reader_pagination/` with:

- `epub_paginator.dart`
- `layout_measurer.dart`
- `page_layout_model.dart`
- `epub_pagination_cache_service.dart`
- `locator_mapper.dart`

### 9.4 Reader Engine Modules

Create `lib/presentation/pages/reader/engines/` with:

- `reader_content_engine.dart`
- `txt_reader_engine.dart`
- `epub_reader_engine.dart`

### 9.5 Provider Additions

Add providers under `lib/core/providers/`:

- `reader_engine_providers.dart`
- `epub_reader_providers.dart`

### 9.6 Existing File Boundaries

These files should not gain more EPUB-specific business logic:

- `lib/presentation/pages/reader/reader_page.dart`
- `lib/presentation/pages/bookshelf/bookshelf_page.dart`

`lib/flureadium_integration/epub_parser.dart` should become transitional only and eventually leave the main production path.

## 10. Implementation Milestones

### M1. Structural Import and Parsing

Acceptance:

- EPUB imports successfully
- Metadata, cover, and TOC are extracted
- Chapter XHTML is converted into the internal document model

### M2. Single-Chapter Pagination

Acceptance:

- Headings, paragraphs, quotes, bold, italic, separators, and images render correctly
- One-screen-per-page horizontal pagination works
- Long paragraphs split correctly
- Images render without distortion

### M3. Reader Shell Integration

Acceptance:

- EPUB opens in the existing reader shell
- Theme, background, controls, and TOC integrate cleanly
- TOC jump and progress restore work
- Reflow after typography changes keeps position stable

### M4. Stability and Performance

Acceptance:

- Mainstream reflowable EPUB files open reliably
- Large books remain usable
- Continuous page turning is stable
- Failures degrade gracefully rather than breaking the reader

## 11. Testing Strategy

### 11.1 Parsing Tests

Use fixture EPUB files to validate:

- metadata
- spine order
- TOC extraction
- chapter loading
- resource resolution

### 11.2 Document Model Tests

Validate XHTML normalization into block and inline nodes.

### 11.3 Pagination Tests

Validate:

- long paragraph splitting
- heading page-break behavior
- quote continuation
- image scaling and dedicated image pages
- locator to page mapping
- locator remapping after style changes

### 11.4 Integration Tests

Validate:

- import EPUB
- open from bookshelf
- page turning
- TOC jumping
- exit and restore
- typography changes with stable reflow position

## 12. Risks and Controls

### Main Risks

- EPUB format variability and malformed content
- style support scope creeping beyond phase 1
- unstable pagination and restore behavior
- memory or performance issues on large books
- reader shell coupling causing TXT regressions

### Controls

- Keep phase 1 scope strict
- Support only reflowable EPUB first
- Keep EPUB locator independent from TXT progress format
- Keep EPUB pagination independent from TXT text slicing
- Separate structure cache from pagination cache
- Keep `ReaderPage` focused on shell responsibilities

## 13. Final Decision Summary

This design chooses:

- Real EPUB parsing over TXT flattening
- A normalized internal document model over direct HTML or pure TXT reuse
- One-screen-per-page pagination in phase 1
- Partial rich-style preservation with image support
- A unified reader shell with a separate EPUB content engine

This is the smallest design that still preserves long-term architectural value.
