-- ============================================================
-- BANCO DE DADOS: DUAL ECOMMERCE + DATA SCIENCE PLATFORM
-- Versão: 2.0 | Compatível com PostgreSQL 14+
-- Descrição: Banco robusto para duas lojas virtuais com
--            suporte completo a Machine Learning e Analytics
-- ============================================================

-- ==========================
-- EXTENSÕES
-- ==========================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- ==========================
-- SCHEMAS
-- ==========================
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS catalog;
CREATE SCHEMA IF NOT EXISTS commerce;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS ml;
CREATE SCHEMA IF NOT EXISTS admin;

-- ============================================================
-- SCHEMA: CORE (Identidade das lojas, usuários, autenticação)
-- ============================================================

-- Lojas virtuais
CREATE TABLE core.stores (
    store_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_code      VARCHAR(20) UNIQUE NOT NULL,   -- ex: 'LOJA_A', 'LOJA_B'
    store_name      VARCHAR(100) NOT NULL,
    store_slug      VARCHAR(100) UNIQUE NOT NULL,
    domain          VARCHAR(255) UNIQUE,
    logo_url        TEXT,
    favicon_url     TEXT,
    primary_color   VARCHAR(7),
    secondary_color VARCHAR(7),
    currency        CHAR(3) DEFAULT 'BRL',
    timezone        VARCHAR(50) DEFAULT 'America/Sao_Paulo',
    locale          VARCHAR(10) DEFAULT 'pt-BR',
    is_active       BOOLEAN DEFAULT TRUE,
    theme_config    JSONB DEFAULT '{}',
    meta_config     JSONB DEFAULT '{}',         -- SEO, open graph
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Perfis de cliente (compartilhados ou por loja)
CREATE TABLE core.customers (
    customer_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id            UUID NOT NULL REFERENCES core.stores(store_id),
    email               VARCHAR(255) NOT NULL,
    email_verified      BOOLEAN DEFAULT FALSE,
    email_verified_at   TIMESTAMPTZ,
    password_hash       TEXT NOT NULL,
    salt                TEXT NOT NULL,
    first_name          VARCHAR(100),
    last_name           VARCHAR(100),
    display_name        VARCHAR(200),
    phone               VARCHAR(30),
    phone_verified      BOOLEAN DEFAULT FALSE,
    cpf                 VARCHAR(14),
    birth_date          DATE,
    gender              VARCHAR(20),  -- 'M','F','NB','prefer_not_to_say'
    avatar_url          TEXT,
    is_active           BOOLEAN DEFAULT TRUE,
    is_blocked          BOOLEAN DEFAULT FALSE,
    block_reason        TEXT,
    newsletter_opt_in   BOOLEAN DEFAULT FALSE,
    sms_opt_in          BOOLEAN DEFAULT FALSE,
    push_opt_in         BOOLEAN DEFAULT FALSE,
    preferred_language  VARCHAR(10) DEFAULT 'pt',
    -- ML / Segmentação
    customer_segment    VARCHAR(50),   -- 'vip','regular','at_risk','new','churned'
    ltv_score           NUMERIC(10,2), -- Lifetime Value calculado
    churn_probability   NUMERIC(5,4),  -- 0.0 a 1.0
    acquisition_channel VARCHAR(100),
    referral_code       VARCHAR(50),
    referred_by         UUID REFERENCES core.customers(customer_id),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    last_login_at       TIMESTAMPTZ,
    UNIQUE(store_id, email)
);

-- Sessões de autenticação
CREATE TABLE core.customer_sessions (
    session_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id     UUID NOT NULL REFERENCES core.customers(customer_id) ON DELETE CASCADE,
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    token_hash      TEXT NOT NULL UNIQUE,
    refresh_token   TEXT,
    device_type     VARCHAR(50),   -- 'mobile','desktop','tablet'
    device_os       VARCHAR(50),
    browser         VARCHAR(100),
    browser_version VARCHAR(50),
    ip_address      INET,
    user_agent      TEXT,
    geolocation     JSONB,         -- {country, state, city, lat, lng}
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    expires_at      TIMESTAMPTZ NOT NULL,
    last_activity   TIMESTAMPTZ DEFAULT NOW()
);

-- Endereços dos clientes
CREATE TABLE core.customer_addresses (
    address_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id     UUID NOT NULL REFERENCES core.customers(customer_id) ON DELETE CASCADE,
    label           VARCHAR(50) DEFAULT 'Casa',  -- 'Casa','Trabalho','Outro'
    recipient_name  VARCHAR(200),
    street          VARCHAR(255) NOT NULL,
    number          VARCHAR(20),
    complement      VARCHAR(100),
    neighborhood    VARCHAR(100),
    city            VARCHAR(100) NOT NULL,
    state           CHAR(2) NOT NULL,
    country         CHAR(2) DEFAULT 'BR',
    zip_code        VARCHAR(10) NOT NULL,
    is_default      BOOLEAN DEFAULT FALSE,
    latitude        NUMERIC(10,8),
    longitude       NUMERIC(11,8),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Usuários administrativos
CREATE TABLE admin.admin_users (
    admin_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID REFERENCES core.stores(store_id),  -- NULL = super admin
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   TEXT NOT NULL,
    salt            TEXT NOT NULL,
    full_name       VARCHAR(200) NOT NULL,
    role            VARCHAR(50) NOT NULL, -- 'superadmin','manager','operator','viewer'
    permissions     JSONB DEFAULT '{}',   -- permissões granulares
    is_active       BOOLEAN DEFAULT TRUE,
    two_fa_enabled  BOOLEAN DEFAULT FALSE,
    two_fa_secret   TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    last_login_at   TIMESTAMPTZ,
    last_login_ip   INET
);

-- Log de ações administrativas (auditoria)
CREATE TABLE admin.audit_log (
    log_id          BIGSERIAL PRIMARY KEY,
    admin_id        UUID REFERENCES admin.admin_users(admin_id),
    store_id        UUID REFERENCES core.stores(store_id),
    action          VARCHAR(100) NOT NULL,  -- 'product.create','order.cancel',...
    entity_type     VARCHAR(100),
    entity_id       UUID,
    old_values      JSONB,
    new_values      JSONB,
    ip_address      INET,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SCHEMA: CATALOG (Produtos, categorias, estoque)
-- ============================================================

-- Categorias de produtos (árvore)
CREATE TABLE catalog.categories (
    category_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    parent_id       UUID REFERENCES catalog.categories(category_id),
    name            VARCHAR(200) NOT NULL,
    slug            VARCHAR(200) NOT NULL,
    description     TEXT,
    image_url       TEXT,
    icon            VARCHAR(100),
    position        INT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    meta_title      VARCHAR(200),
    meta_description TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(store_id, slug)
);

-- Marcas / Fornecedores
CREATE TABLE catalog.brands (
    brand_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    name            VARCHAR(200) NOT NULL,
    slug            VARCHAR(200) NOT NULL,
    logo_url        TEXT,
    website         TEXT,
    country_origin  CHAR(2),
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(store_id, slug)
);

-- Produtos
CREATE TABLE catalog.products (
    product_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    category_id     UUID REFERENCES catalog.categories(category_id),
    brand_id        UUID REFERENCES catalog.brands(brand_id),
    sku             VARCHAR(100) NOT NULL,
    name            VARCHAR(500) NOT NULL,
    slug            VARCHAR(500) NOT NULL,
    short_description TEXT,
    description     TEXT,
    status          VARCHAR(20) DEFAULT 'draft',  -- draft,active,paused,discontinued
    product_type    VARCHAR(30) DEFAULT 'simple', -- simple,variable,bundle,digital
    -- Preços
    base_price      NUMERIC(12,2) NOT NULL,
    sale_price      NUMERIC(12,2),
    cost_price      NUMERIC(12,2),
    tax_rate        NUMERIC(5,4) DEFAULT 0,
    -- Logística
    weight_g        INT,           -- peso em gramas
    height_cm       NUMERIC(8,2),
    width_cm        NUMERIC(8,2),
    depth_cm        NUMERIC(8,2),
    requires_shipping BOOLEAN DEFAULT TRUE,
    free_shipping   BOOLEAN DEFAULT FALSE,
    -- SEO e visibilidade
    meta_title      VARCHAR(200),
    meta_description VARCHAR(500),
    tags            TEXT[],
    -- Atributos extras
    attributes      JSONB DEFAULT '{}',
    -- ML Features
    avg_rating      NUMERIC(3,2) DEFAULT 0,
    review_count    INT DEFAULT 0,
    view_count      BIGINT DEFAULT 0,
    purchase_count  BIGINT DEFAULT 0,
    wishlist_count  INT DEFAULT 0,
    return_count    INT DEFAULT 0,
    popularity_score NUMERIC(10,4) DEFAULT 0,
    -- Timestamps
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    published_at    TIMESTAMPTZ,
    UNIQUE(store_id, sku),
    UNIQUE(store_id, slug)
);

-- Variações de produto (cor, tamanho, etc.)
CREATE TABLE catalog.product_variants (
    variant_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id      UUID NOT NULL REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    sku             VARCHAR(100) NOT NULL UNIQUE,
    name            VARCHAR(300),
    attributes      JSONB NOT NULL DEFAULT '{}', -- {"color":"Azul","size":"M"}
    price_modifier  NUMERIC(10,2) DEFAULT 0,
    cost_price      NUMERIC(12,2),
    barcode         VARCHAR(100),
    weight_g        INT,
    image_url       TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    position        INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Estoque por variante e localização
CREATE TABLE catalog.inventory (
    inventory_id    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    variant_id      UUID NOT NULL REFERENCES catalog.product_variants(variant_id),
    location        VARCHAR(100) DEFAULT 'main', -- centro de distribuição
    quantity        INT NOT NULL DEFAULT 0,
    reserved        INT NOT NULL DEFAULT 0,       -- reservado em pedidos pendentes
    min_quantity    INT DEFAULT 0,               -- gatilho de reposição
    max_quantity    INT,
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(variant_id, location)
);

-- Histórico de movimentação de estoque
CREATE TABLE catalog.inventory_movements (
    movement_id     BIGSERIAL PRIMARY KEY,
    variant_id      UUID NOT NULL REFERENCES catalog.product_variants(variant_id),
    location        VARCHAR(100),
    movement_type   VARCHAR(30) NOT NULL, -- purchase,sale,return,adjustment,transfer
    quantity_change INT NOT NULL,
    quantity_before INT NOT NULL,
    quantity_after  INT NOT NULL,
    reference_type  VARCHAR(50),   -- 'order','return','manual'
    reference_id    UUID,
    notes           TEXT,
    admin_id        UUID REFERENCES admin.admin_users(admin_id),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Imagens de produto
CREATE TABLE catalog.product_images (
    image_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id      UUID NOT NULL REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    variant_id      UUID REFERENCES catalog.product_variants(variant_id),
    url             TEXT NOT NULL,
    alt_text        VARCHAR(300),
    position        INT DEFAULT 0,
    is_primary      BOOLEAN DEFAULT FALSE,
    width_px        INT,
    height_px       INT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Avaliações de produto
CREATE TABLE catalog.product_reviews (
    review_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id      UUID NOT NULL REFERENCES catalog.products(product_id),
    customer_id     UUID NOT NULL REFERENCES core.customers(customer_id),
    order_id        UUID,   -- FK adicionada após criação da tabela orders
    rating          SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title           VARCHAR(200),
    body            TEXT,
    pros            TEXT[],
    cons            TEXT[],
    images          TEXT[],
    is_verified_purchase BOOLEAN DEFAULT FALSE,
    is_approved     BOOLEAN DEFAULT FALSE,
    helpful_votes   INT DEFAULT 0,
    not_helpful_votes INT DEFAULT 0,
    -- NLP / Sentiment
    sentiment_score NUMERIC(4,3),  -- -1.0 a 1.0
    sentiment_label VARCHAR(20),   -- positive, neutral, negative
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(customer_id, product_id, order_id)
);

-- ============================================================
-- SCHEMA: COMMERCE (Pedidos, carrinhos, pagamentos, cupons)
-- ============================================================

-- Carrinhos de compra
CREATE TABLE commerce.carts (
    cart_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    customer_id     UUID REFERENCES core.customers(customer_id),
    session_key     VARCHAR(255),    -- para usuários anônimos
    status          VARCHAR(20) DEFAULT 'active', -- active,converted,abandoned,expired
    currency        CHAR(3) DEFAULT 'BRL',
    -- Valores
    subtotal        NUMERIC(12,2) DEFAULT 0,
    discount_total  NUMERIC(12,2) DEFAULT 0,
    shipping_total  NUMERIC(12,2) DEFAULT 0,
    tax_total       NUMERIC(12,2) DEFAULT 0,
    grand_total     NUMERIC(12,2) DEFAULT 0,
    -- Dados de abandono (para ML de recuperação)
    abandoned_at        TIMESTAMPTZ,
    recovery_email_sent BOOLEAN DEFAULT FALSE,
    recovery_email_at   TIMESTAMPTZ,
    recovered_at        TIMESTAMPTZ,
    -- Metadados de sessão para ML
    utm_source      VARCHAR(200),
    utm_medium      VARCHAR(200),
    utm_campaign    VARCHAR(200),
    utm_term        VARCHAR(200),
    utm_content     VARCHAR(200),
    referrer_url    TEXT,
    landing_page    TEXT,
    device_type     VARCHAR(50),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Itens do carrinho
CREATE TABLE commerce.cart_items (
    item_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cart_id         UUID NOT NULL REFERENCES commerce.carts(cart_id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES catalog.products(product_id),
    variant_id      UUID REFERENCES catalog.product_variants(variant_id),
    quantity        INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price      NUMERIC(12,2) NOT NULL,
    original_price  NUMERIC(12,2),
    discount_amount NUMERIC(12,2) DEFAULT 0,
    -- Snapshot do produto no momento da adição
    product_snapshot JSONB,   -- {name, sku, image_url, attributes}
    added_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Cupons de desconto
CREATE TABLE commerce.coupons (
    coupon_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    code            VARCHAR(100) NOT NULL,
    description     VARCHAR(500),
    discount_type   VARCHAR(20) NOT NULL,  -- percentage,fixed,free_shipping,buy_x_get_y
    discount_value  NUMERIC(10,2) NOT NULL,
    min_order_value NUMERIC(12,2) DEFAULT 0,
    max_discount    NUMERIC(12,2),         -- teto para desconto percentual
    -- Aplicabilidade
    applies_to      VARCHAR(30) DEFAULT 'all', -- all,products,categories,customers
    applicable_ids  UUID[],
    -- Limites
    max_uses        INT,
    max_uses_per_customer INT DEFAULT 1,
    uses_count      INT DEFAULT 0,
    -- Validade
    starts_at       TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    created_by      UUID REFERENCES admin.admin_users(admin_id),
    UNIQUE(store_id, code)
);

-- Pedidos
CREATE TABLE commerce.orders (
    order_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    customer_id     UUID NOT NULL REFERENCES core.customers(customer_id),
    order_number    VARCHAR(50) NOT NULL,  -- ex: 'ORD-2024-000001'
    status          VARCHAR(30) NOT NULL DEFAULT 'pending',
    -- pending, confirmed, processing, shipped, delivered, cancelled, refunded
    payment_status  VARCHAR(30) DEFAULT 'pending',
    -- pending, paid, partial, refunded, failed, chargeback
    -- Valores
    currency        CHAR(3) DEFAULT 'BRL',
    subtotal        NUMERIC(12,2) NOT NULL,
    discount_total  NUMERIC(12,2) DEFAULT 0,
    shipping_total  NUMERIC(12,2) DEFAULT 0,
    tax_total       NUMERIC(12,2) DEFAULT 0,
    grand_total     NUMERIC(12,2) NOT NULL,
    -- Cupom aplicado
    coupon_id       UUID REFERENCES commerce.coupons(coupon_id),
    coupon_code     VARCHAR(100),
    -- Endereço de entrega (snapshot)
    shipping_address JSONB NOT NULL,
    billing_address  JSONB,
    -- Frete
    shipping_method  VARCHAR(100),
    tracking_code    VARCHAR(200),
    estimated_delivery DATE,
    shipped_at      TIMESTAMPTZ,
    delivered_at    TIMESTAMPTZ,
    -- Rastreamento de origem (para ML de atribuição)
    cart_id         UUID REFERENCES commerce.carts(cart_id),
    utm_source      VARCHAR(200),
    utm_medium      VARCHAR(200),
    utm_campaign    VARCHAR(200),
    device_type     VARCHAR(50),
    ip_address      INET,
    -- Notas
    customer_notes  TEXT,
    internal_notes  TEXT,
    -- Timestamps
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    confirmed_at    TIMESTAMPTZ,
    cancelled_at    TIMESTAMPTZ,
    cancel_reason   TEXT,
    UNIQUE(store_id, order_number)
);

-- Itens do pedido
CREATE TABLE commerce.order_items (
    order_item_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id        UUID NOT NULL REFERENCES commerce.orders(order_id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES catalog.products(product_id),
    variant_id      UUID REFERENCES catalog.product_variants(variant_id),
    sku             VARCHAR(100) NOT NULL,
    product_name    VARCHAR(500) NOT NULL,
    variant_attrs   JSONB DEFAULT '{}',
    quantity        INT NOT NULL,
    unit_price      NUMERIC(12,2) NOT NULL,
    original_price  NUMERIC(12,2),
    discount_amount NUMERIC(12,2) DEFAULT 0,
    tax_amount      NUMERIC(12,2) DEFAULT 0,
    total           NUMERIC(12,2) NOT NULL,
    cost_price      NUMERIC(12,2),  -- para cálculo de margem
    product_snapshot JSONB,
    is_returned     BOOLEAN DEFAULT FALSE,
    returned_qty    INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Pagamentos
CREATE TABLE commerce.payments (
    payment_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id        UUID NOT NULL REFERENCES commerce.orders(order_id),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    payment_method  VARCHAR(50) NOT NULL, -- credit_card,debit_card,pix,boleto,wallet
    gateway         VARCHAR(50),          -- stripe,pagseguro,mercadopago,cielo
    gateway_txn_id  TEXT,                 -- ID na gateway
    gateway_response JSONB,              -- resposta completa da gateway
    amount          NUMERIC(12,2) NOT NULL,
    currency        CHAR(3) DEFAULT 'BRL',
    status          VARCHAR(30) NOT NULL DEFAULT 'pending',
    -- pending, processing, completed, failed, refunded, cancelled
    installments    SMALLINT DEFAULT 1,
    installment_value NUMERIC(12,2),
    -- Dados de cartão (tokenizados)
    card_last4      CHAR(4),
    card_brand      VARCHAR(30),
    card_holder     VARCHAR(200),
    -- Anti-fraude
    fraud_score     NUMERIC(5,4),
    is_fraud_flagged BOOLEAN DEFAULT FALSE,
    fraud_reason    TEXT,
    -- Timestamps
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    processed_at    TIMESTAMPTZ,
    refunded_at     TIMESTAMPTZ,
    refund_amount   NUMERIC(12,2)
);

-- Devoluções / RMA
CREATE TABLE commerce.returns (
    return_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id        UUID NOT NULL REFERENCES commerce.orders(order_id),
    customer_id     UUID NOT NULL REFERENCES core.customers(customer_id),
    return_number   VARCHAR(50) UNIQUE NOT NULL,
    status          VARCHAR(30) DEFAULT 'requested',
    -- requested, approved, shipped, received, refunded, rejected
    reason          VARCHAR(100) NOT NULL,
    -- defective, wrong_item, changed_mind, damaged, not_as_described
    description     TEXT,
    refund_method   VARCHAR(50),  -- original_payment, store_credit, exchange
    refund_amount   NUMERIC(12,2),
    images          TEXT[],
    admin_notes     TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);

-- Itens da devolução
CREATE TABLE commerce.return_items (
    return_item_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    return_id       UUID NOT NULL REFERENCES commerce.returns(return_id) ON DELETE CASCADE,
    order_item_id   UUID NOT NULL REFERENCES commerce.order_items(order_item_id),
    quantity        INT NOT NULL,
    reason          VARCHAR(100),
    condition       VARCHAR(50)  -- new, used, damaged
);

-- Lista de desejos
CREATE TABLE commerce.wishlists (
    wishlist_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id     UUID NOT NULL REFERENCES core.customers(customer_id),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    name            VARCHAR(200) DEFAULT 'Minha lista',
    is_public       BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE commerce.wishlist_items (
    item_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    wishlist_id     UUID NOT NULL REFERENCES commerce.wishlists(wishlist_id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES catalog.products(product_id),
    variant_id      UUID REFERENCES catalog.product_variants(variant_id),
    added_at        TIMESTAMPTZ DEFAULT NOW(),
    price_at_addition NUMERIC(12,2),
    UNIQUE(wishlist_id, product_id, variant_id)
);

-- Crédito de loja / Cashback
CREATE TABLE commerce.store_credits (
    credit_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id     UUID NOT NULL REFERENCES core.customers(customer_id),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    credit_type     VARCHAR(30), -- cashback, refund, gift, promotional
    amount          NUMERIC(12,2) NOT NULL,
    used_amount     NUMERIC(12,2) DEFAULT 0,
    balance         NUMERIC(12,2) NOT NULL,
    reference_id    UUID,
    notes           TEXT,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SCHEMA: ANALYTICS (Eventos, comportamento, métricas para ML)
-- ============================================================

-- Eventos de navegação e interação do usuário (principal tabela para ML)
CREATE TABLE analytics.events (
    event_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    customer_id     UUID REFERENCES core.customers(customer_id),
    session_id      UUID REFERENCES core.customer_sessions(session_id),
    anonymous_id    VARCHAR(100),     -- fingerprint para usuários não logados
    event_type      VARCHAR(100) NOT NULL,
    -- page_view, product_view, add_to_cart, remove_from_cart,
    -- checkout_start, checkout_step, purchase, search,
    -- filter_apply, sort_change, image_click, video_play,
    -- review_read, review_submit, wishlist_add, share,
    -- coupon_apply, login, logout, register, password_reset,
    -- notification_click, banner_click, recommendation_click
    event_category  VARCHAR(50),
    event_label     VARCHAR(200),
    -- Contexto
    page_url        TEXT,
    page_title      VARCHAR(300),
    page_type       VARCHAR(50),  -- home,category,product,cart,checkout,account,search
    referrer_url    TEXT,
    -- Entidades relacionadas
    product_id      UUID REFERENCES catalog.products(product_id),
    category_id     UUID REFERENCES catalog.categories(category_id),
    order_id        UUID REFERENCES commerce.orders(order_id),
    cart_id         UUID REFERENCES commerce.carts(cart_id),
    -- Dados de contexto
    properties      JSONB DEFAULT '{}',  -- dados específicos por tipo de evento
    -- Sessão e ambiente
    session_number  INT,               -- quantas sessões este usuário já teve
    device_type     VARCHAR(50),
    device_os       VARCHAR(50),
    browser         VARCHAR(100),
    screen_width    SMALLINT,
    screen_height   SMALLINT,
    viewport_width  SMALLINT,
    viewport_height SMALLINT,
    -- Posicionamento na página
    scroll_depth_pct SMALLINT,         -- 0-100
    time_on_page_sec INT,
    -- Geolocalização
    ip_address      INET,
    country         CHAR(2),
    state           VARCHAR(50),
    city            VARCHAR(100),
    -- Marketing
    utm_source      VARCHAR(200),
    utm_medium      VARCHAR(200),
    utm_campaign    VARCHAR(200),
    utm_term        VARCHAR(200),
    utm_content     VARCHAR(200),
    -- Experimentos A/B
    ab_variants     JSONB DEFAULT '{}', -- {"exp_checkout":"variant_b"}
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (occurred_at);

-- Partições mensais de eventos (performance em consultas de analytics)
CREATE TABLE analytics.events_2024_01 PARTITION OF analytics.events
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE analytics.events_2024_02 PARTITION OF analytics.events
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
CREATE TABLE analytics.events_2025_01 PARTITION OF analytics.events
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE analytics.events_default PARTITION OF analytics.events DEFAULT;

-- Sessões de usuário (para análise de comportamento)
CREATE TABLE analytics.user_sessions (
    us_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    customer_id     UUID REFERENCES core.customers(customer_id),
    session_id      UUID REFERENCES core.customer_sessions(session_id),
    anonymous_id    VARCHAR(100),
    -- Métricas da sessão
    session_start   TIMESTAMPTZ NOT NULL,
    session_end     TIMESTAMPTZ,
    duration_sec    INT,
    page_views      INT DEFAULT 0,
    events_count    INT DEFAULT 0,
    -- Produtos interagidos
    products_viewed INT DEFAULT 0,
    products_added_cart INT DEFAULT 0,
    categories_visited TEXT[],
    -- Resultado
    converted       BOOLEAN DEFAULT FALSE,
    order_id        UUID REFERENCES commerce.orders(order_id),
    order_value     NUMERIC(12,2),
    -- Contexto
    entry_page      TEXT,
    exit_page       TEXT,
    entry_page_type VARCHAR(50),
    bounce          BOOLEAN DEFAULT FALSE,  -- saiu sem interagir
    device_type     VARCHAR(50),
    utm_source      VARCHAR(200),
    utm_medium      VARCHAR(200),
    utm_campaign    VARCHAR(200),
    -- Funnel de checkout
    reached_cart    BOOLEAN DEFAULT FALSE,
    reached_checkout BOOLEAN DEFAULT FALSE,
    reached_payment BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Buscas realizadas na loja
CREATE TABLE analytics.searches (
    search_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    customer_id     UUID REFERENCES core.customers(customer_id),
    session_id      UUID REFERENCES core.customer_sessions(session_id),
    query           VARCHAR(500) NOT NULL,
    query_normalized VARCHAR(500),   -- lowercase, stemmed
    results_count   INT DEFAULT 0,
    clicked_product_id UUID REFERENCES catalog.products(product_id),
    clicked_position INT,            -- posição do resultado clicado
    converted       BOOLEAN DEFAULT FALSE,
    filters_applied JSONB DEFAULT '{}',
    sort_by         VARCHAR(50),
    device_type     VARCHAR(50),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Funil de conversão (snapshots do funil por período)
CREATE TABLE analytics.conversion_funnels (
    funnel_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    date            DATE NOT NULL,
    segment         VARCHAR(50) DEFAULT 'all',  -- all,new_users,returning,mobile,desktop
    -- Métricas do funil
    sessions_total      BIGINT DEFAULT 0,
    sessions_product    BIGINT DEFAULT 0,  -- visualizaram produto
    sessions_cart       BIGINT DEFAULT 0,  -- adicionaram ao carrinho
    sessions_checkout   BIGINT DEFAULT 0,  -- iniciaram checkout
    sessions_payment    BIGINT DEFAULT 0,  -- chegaram ao pagamento
    sessions_converted  BIGINT DEFAULT 0,  -- converteram
    -- Revenue
    revenue_total       NUMERIC(15,2) DEFAULT 0,
    orders_count        BIGINT DEFAULT 0,
    avg_order_value     NUMERIC(10,2) DEFAULT 0,
    UNIQUE(store_id, date, segment)
);

-- Métricas diárias por produto (para análise de tendências)
CREATE TABLE analytics.product_daily_metrics (
    metric_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id      UUID NOT NULL REFERENCES catalog.products(product_id),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    date            DATE NOT NULL,
    -- Engajamento
    views           INT DEFAULT 0,
    unique_viewers  INT DEFAULT 0,
    add_to_carts    INT DEFAULT 0,
    wishlist_adds   INT DEFAULT 0,
    -- Vendas
    units_sold      INT DEFAULT 0,
    revenue         NUMERIC(12,2) DEFAULT 0,
    returns         INT DEFAULT 0,
    -- Estoque
    stock_level     INT,
    -- Preço
    price           NUMERIC(12,2),
    -- Derivadas
    conversion_rate NUMERIC(6,4),   -- add_to_carts / views
    purchase_rate   NUMERIC(6,4),   -- units_sold / views
    UNIQUE(product_id, store_id, date)
);

-- Métricas diárias por cliente (RFM e outros indicadores)
CREATE TABLE analytics.customer_daily_metrics (
    metric_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id     UUID NOT NULL REFERENCES core.customers(customer_id),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    date            DATE NOT NULL,
    sessions_count  INT DEFAULT 0,
    time_spent_sec  INT DEFAULT 0,
    pages_viewed    INT DEFAULT 0,
    products_viewed INT DEFAULT 0,
    searches_count  INT DEFAULT 0,
    orders_count    INT DEFAULT 0,
    order_value     NUMERIC(12,2) DEFAULT 0,
    UNIQUE(customer_id, store_id, date)
);

-- ============================================================
-- SCHEMA: ML (Features, modelos, predições, segmentos)
-- ============================================================

-- Features calculadas por cliente (tabela principal para ML)
CREATE TABLE ml.customer_features (
    feature_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id         UUID NOT NULL REFERENCES core.customers(customer_id),
    store_id            UUID NOT NULL REFERENCES core.stores(store_id),
    computed_at         TIMESTAMPTZ DEFAULT NOW(),
    -- === RFM (Recência, Frequência, Valor Monetário) ===
    days_since_last_order   INT,
    days_since_last_visit   INT,
    order_frequency_days    NUMERIC(8,2),  -- média de dias entre pedidos
    total_orders            INT DEFAULT 0,
    total_spent             NUMERIC(15,2) DEFAULT 0,
    avg_order_value         NUMERIC(10,2) DEFAULT 0,
    max_order_value         NUMERIC(10,2) DEFAULT 0,
    rfm_recency_score       SMALLINT,      -- 1-5
    rfm_frequency_score     SMALLINT,
    rfm_monetary_score      SMALLINT,
    rfm_total_score         SMALLINT,
    rfm_segment             VARCHAR(30),   -- champions, loyal, potential_loyal, etc.
    -- === Comportamento de Navegação ===
    total_sessions          INT DEFAULT 0,
    avg_session_duration_sec INT,
    avg_pages_per_session   NUMERIC(6,2),
    total_products_viewed   INT DEFAULT 0,
    unique_categories_visited INT DEFAULT 0,
    total_searches          INT DEFAULT 0,
    search_to_purchase_rate NUMERIC(5,4),
    -- === Preferências ===
    preferred_categories    TEXT[],        -- top 3 categorias mais visitadas
    preferred_brands        TEXT[],        -- top 3 marcas
    preferred_price_range_min NUMERIC(10,2),
    preferred_price_range_max NUMERIC(10,2),
    device_preference       VARCHAR(20),   -- mobile, desktop, tablet
    peak_shopping_hour      SMALLINT,      -- 0-23
    peak_shopping_weekday   SMALLINT,      -- 0=Domingo a 6=Sábado
    -- === Engajamento ===
    email_open_rate         NUMERIC(5,4),
    email_click_rate        NUMERIC(5,4),
    push_notification_ctr   NUMERIC(5,4),
    wishlist_items_count    INT DEFAULT 0,
    cart_abandonment_rate   NUMERIC(5,4),  -- carrinhos abandonados / carrinhos criados
    avg_cart_abandonment_value NUMERIC(10,2),
    -- === Risco e Saúde ===
    return_rate             NUMERIC(5,4),  -- itens devolvidos / comprados
    chargeback_count        INT DEFAULT 0,
    days_since_acquisition  INT,
    is_first_purchase_done  BOOLEAN DEFAULT FALSE,
    days_to_first_purchase  INT,           -- dias entre cadastro e 1a compra
    -- === Predições (atualizadas pelo modelo) ===
    predicted_ltv_90d       NUMERIC(12,2),
    predicted_ltv_365d      NUMERIC(12,2),
    churn_probability       NUMERIC(5,4),
    churn_risk_level        VARCHAR(20),   -- low, medium, high, critical
    next_purchase_prob_30d  NUMERIC(5,4),
    upsell_probability      NUMERIC(5,4),
    price_sensitivity_score NUMERIC(5,4),  -- 0=insensível, 1=muito sensível
    loyalty_score           NUMERIC(5,4),
    customer_health_score   NUMERIC(5,4),  -- 0-1 score geral
    UNIQUE(customer_id, store_id)
);

-- Segmentos de clientes (dinâmicos)
CREATE TABLE ml.customer_segments (
    segment_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    segment_type    VARCHAR(30), -- rfm, behavioral, predictive, demographic
    criteria        JSONB NOT NULL,  -- regras do segmento
    customer_count  INT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    auto_refresh    BOOLEAN DEFAULT TRUE,
    last_computed   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(store_id, name)
);

-- Associação cliente-segmento
CREATE TABLE ml.customer_segment_members (
    member_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    segment_id      UUID NOT NULL REFERENCES ml.customer_segments(segment_id) ON DELETE CASCADE,
    customer_id     UUID NOT NULL REFERENCES core.customers(customer_id),
    score           NUMERIC(5,4),   -- score de pertencimento
    added_at        TIMESTAMPTZ DEFAULT NOW(),
    expires_at      TIMESTAMPTZ,
    UNIQUE(segment_id, customer_id)
);

-- Recomendações de produto por cliente
CREATE TABLE ml.product_recommendations (
    rec_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    customer_id     UUID REFERENCES core.customers(customer_id),
    segment_id      UUID REFERENCES ml.customer_segments(segment_id),
    context         VARCHAR(50) NOT NULL,
    -- homepage, product_page, cart, email, post_purchase
    algorithm       VARCHAR(50), -- collaborative_filtering, content_based, hybrid, trending
    product_id      UUID NOT NULL REFERENCES catalog.products(product_id),
    position        SMALLINT NOT NULL,
    score           NUMERIC(8,6),
    -- Resultado (atualizado quando o cliente interage)
    was_shown       BOOLEAN DEFAULT FALSE,
    was_clicked     BOOLEAN DEFAULT FALSE,
    was_purchased   BOOLEAN DEFAULT FALSE,
    shown_at        TIMESTAMPTZ,
    clicked_at      TIMESTAMPTZ,
    purchased_at    TIMESTAMPTZ,
    computed_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Versões de modelos de ML
CREATE TABLE ml.model_versions (
    model_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID REFERENCES core.stores(store_id),
    model_name      VARCHAR(100) NOT NULL,
    model_type      VARCHAR(50),   -- churn, ltv, recommendation, fraud, demand_forecast
    version         VARCHAR(20) NOT NULL,
    algorithm       VARCHAR(100),
    hyperparameters JSONB DEFAULT '{}',
    feature_list    TEXT[],
    -- Métricas de desempenho
    metrics         JSONB DEFAULT '{}',  -- {accuracy, precision, recall, f1, auc, rmse}
    training_data_start DATE,
    training_data_end   DATE,
    training_samples    INT,
    is_active       BOOLEAN DEFAULT FALSE,
    deployed_at     TIMESTAMPTZ,
    deprecated_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Predições individuais (log de saídas do modelo)
CREATE TABLE ml.predictions (
    prediction_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_id        UUID NOT NULL REFERENCES ml.model_versions(model_id),
    entity_type     VARCHAR(50) NOT NULL,  -- customer, product, order
    entity_id       UUID NOT NULL,
    prediction_type VARCHAR(50) NOT NULL,  -- churn, ltv, fraud, demand
    score           NUMERIC(10,6),
    label           VARCHAR(100),
    confidence      NUMERIC(5,4),
    features_used   JSONB,
    actual_outcome  VARCHAR(100),     -- preenchido depois para validação
    outcome_at      TIMESTAMPTZ,
    is_correct      BOOLEAN,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Experimentos A/B
CREATE TABLE ml.ab_experiments (
    experiment_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    hypothesis      TEXT,
    status          VARCHAR(20) DEFAULT 'draft', -- draft, running, paused, completed
    traffic_split   JSONB NOT NULL, -- {"control": 50, "variant_a": 50}
    target_metric   VARCHAR(100),  -- conversion_rate, avg_order_value, etc.
    min_sample_size INT,
    significance_level NUMERIC(4,3) DEFAULT 0.05,
    -- Resultado
    winning_variant VARCHAR(50),
    result_metrics  JSONB,
    started_at      TIMESTAMPTZ,
    ended_at        TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Participantes dos experimentos A/B
CREATE TABLE ml.ab_participants (
    participant_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    experiment_id   UUID NOT NULL REFERENCES ml.ab_experiments(experiment_id),
    customer_id     UUID REFERENCES core.customers(customer_id),
    anonymous_id    VARCHAR(100),
    variant         VARCHAR(50) NOT NULL,
    enrolled_at     TIMESTAMPTZ DEFAULT NOW(),
    converted       BOOLEAN DEFAULT FALSE,
    conversion_value NUMERIC(12,2),
    converted_at    TIMESTAMPTZ,
    UNIQUE(experiment_id, customer_id),
    UNIQUE(experiment_id, anonymous_id)
);

-- Previsão de demanda por produto
CREATE TABLE ml.demand_forecasts (
    forecast_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id      UUID NOT NULL REFERENCES catalog.products(product_id),
    variant_id      UUID REFERENCES catalog.product_variants(variant_id),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    model_id        UUID REFERENCES ml.model_versions(model_id),
    forecast_date   DATE NOT NULL,
    horizon_days    INT NOT NULL,    -- quantos dias à frente foi previsto
    predicted_units INT NOT NULL,
    confidence_low  INT,             -- intervalo de confiança inferior
    confidence_high INT,
    actual_units    INT,             -- preenchido depois
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(product_id, variant_id, store_id, forecast_date, horizon_days)
);

-- Alertas automáticos (estoque baixo, anomalias, oportunidades)
CREATE TABLE ml.alerts (
    alert_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID NOT NULL REFERENCES core.stores(store_id),
    alert_type      VARCHAR(50) NOT NULL,
    -- low_stock, demand_spike, churn_risk, anomaly_revenue,
    -- cart_recovery_opportunity, price_optimization
    severity        VARCHAR(20) DEFAULT 'medium', -- low, medium, high, critical
    entity_type     VARCHAR(50),
    entity_id       UUID,
    title           VARCHAR(300),
    description     TEXT,
    data            JSONB DEFAULT '{}',
    is_read         BOOLEAN DEFAULT FALSE,
    is_resolved     BOOLEAN DEFAULT FALSE,
    resolved_by     UUID REFERENCES admin.admin_users(admin_id),
    resolved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ÍNDICES PARA PERFORMANCE
-- ============================================================

-- Core
CREATE INDEX idx_customers_store_email ON core.customers(store_id, email);
CREATE INDEX idx_customers_segment ON core.customers(customer_segment);
CREATE INDEX idx_customers_created ON core.customers(created_at DESC);
CREATE INDEX idx_sessions_customer ON core.customer_sessions(customer_id, is_active);
CREATE INDEX idx_sessions_expires ON core.customer_sessions(expires_at);

-- Catalog
CREATE INDEX idx_products_store_status ON catalog.products(store_id, status);
CREATE INDEX idx_products_category ON catalog.products(category_id);
CREATE INDEX idx_products_tags ON catalog.products USING GIN(tags);
CREATE INDEX idx_products_search ON catalog.products USING GIN(to_tsvector('portuguese', name || ' ' || COALESCE(short_description,'')));
CREATE INDEX idx_inventory_variant ON catalog.inventory(variant_id);

-- Commerce
CREATE INDEX idx_orders_customer ON commerce.orders(customer_id, created_at DESC);
CREATE INDEX idx_orders_store_status ON commerce.orders(store_id, status);
CREATE INDEX idx_orders_created ON commerce.orders(created_at DESC);
CREATE INDEX idx_carts_customer ON commerce.carts(customer_id, status);
CREATE INDEX idx_carts_abandoned ON commerce.carts(status, abandoned_at) WHERE status = 'abandoned';
CREATE INDEX idx_payments_order ON commerce.payments(order_id);

-- Analytics
CREATE INDEX idx_events_customer_type ON analytics.events(customer_id, event_type, occurred_at DESC);
CREATE INDEX idx_events_store_date ON analytics.events(store_id, occurred_at DESC);
CREATE INDEX idx_events_product ON analytics.events(product_id, occurred_at DESC);
CREATE INDEX idx_events_session ON analytics.events(session_id);
CREATE INDEX idx_user_sessions_customer ON analytics.user_sessions(customer_id, session_start DESC);
CREATE INDEX idx_searches_store ON analytics.searches(store_id, created_at DESC);
CREATE INDEX idx_searches_query ON analytics.searches USING GIN(to_tsvector('portuguese', query));
CREATE INDEX idx_product_daily_store_date ON analytics.product_daily_metrics(store_id, date DESC);

-- ML
CREATE INDEX idx_customer_features_store ON ml.customer_features(store_id);
CREATE INDEX idx_customer_features_churn ON ml.customer_features(churn_probability DESC);
CREATE INDEX idx_customer_features_ltv ON ml.customer_features(predicted_ltv_365d DESC);
CREATE INDEX idx_recommendations_customer ON ml.product_recommendations(customer_id, context, computed_at DESC);
CREATE INDEX idx_predictions_entity ON ml.predictions(entity_type, entity_id, prediction_type);
CREATE INDEX idx_alerts_store_unread ON ml.alerts(store_id, is_read, severity) WHERE NOT is_resolved;

-- ============================================================
-- VIEWS PARA ANÁLISE E DASHBOARDS
-- ============================================================

-- View: KPIs gerais da loja
CREATE OR REPLACE VIEW analytics.v_store_kpis AS
SELECT
    s.store_id,
    s.store_name,
    DATE_TRUNC('month', o.created_at) AS month,
    COUNT(DISTINCT o.order_id)        AS total_orders,
    COUNT(DISTINCT o.customer_id)     AS unique_buyers,
    SUM(o.grand_total)                AS gross_revenue,
    SUM(o.discount_total)             AS total_discounts,
    AVG(o.grand_total)                AS avg_order_value,
    COUNT(DISTINCT CASE WHEN o.status = 'cancelled' THEN o.order_id END) AS cancelled_orders,
    SUM(CASE WHEN o.status = 'cancelled' THEN o.grand_total ELSE 0 END)  AS cancelled_revenue
FROM core.stores s
LEFT JOIN commerce.orders o ON o.store_id = s.store_id
GROUP BY s.store_id, s.store_name, DATE_TRUNC('month', o.created_at);

-- View: RFM Scores por cliente
CREATE OR REPLACE VIEW analytics.v_rfm_scores AS
WITH order_stats AS (
    SELECT
        o.customer_id,
        o.store_id,
        MAX(o.created_at)                AS last_order_date,
        COUNT(o.order_id)                AS frequency,
        SUM(o.grand_total)               AS monetary,
        CURRENT_DATE - MAX(o.created_at::DATE) AS recency_days
    FROM commerce.orders o
    WHERE o.status NOT IN ('cancelled','refunded')
    GROUP BY o.customer_id, o.store_id
)
SELECT
    os.customer_id,
    os.store_id,
    os.recency_days,
    os.frequency,
    os.monetary,
    -- Scoring 1-5 por percentil
    NTILE(5) OVER (PARTITION BY os.store_id ORDER BY os.recency_days DESC)  AS r_score,
    NTILE(5) OVER (PARTITION BY os.store_id ORDER BY os.frequency)           AS f_score,
    NTILE(5) OVER (PARTITION BY os.store_id ORDER BY os.monetary)            AS m_score
FROM order_stats os;

-- View: Funil de conversão diário
CREATE OR REPLACE VIEW analytics.v_daily_funnel AS
SELECT
    store_id,
    DATE(occurred_at) AS date,
    COUNT(DISTINCT session_id) FILTER (WHERE event_type = 'page_view')        AS sessions,
    COUNT(DISTINCT session_id) FILTER (WHERE event_type = 'product_view')     AS product_views,
    COUNT(DISTINCT session_id) FILTER (WHERE event_type = 'add_to_cart')      AS cart_adds,
    COUNT(DISTINCT session_id) FILTER (WHERE event_type = 'checkout_start')   AS checkouts,
    COUNT(DISTINCT session_id) FILTER (WHERE event_type = 'purchase')         AS purchases,
    ROUND(
        COUNT(DISTINCT session_id) FILTER (WHERE event_type = 'purchase')::NUMERIC /
        NULLIF(COUNT(DISTINCT session_id) FILTER (WHERE event_type = 'page_view'), 0) * 100
    , 2) AS overall_conversion_pct
FROM analytics.events
GROUP BY store_id, DATE(occurred_at);

-- View: Produtos mais vendidos com métricas
CREATE OR REPLACE VIEW analytics.v_product_performance AS
SELECT
    p.product_id,
    p.store_id,
    p.name,
    p.base_price,
    p.avg_rating,
    p.review_count,
    p.view_count,
    p.purchase_count,
    COALESCE(SUM(oi.total), 0)                      AS total_revenue,
    COALESCE(SUM(oi.quantity), 0)                   AS total_units_sold,
    COALESCE(AVG(oi.unit_price), p.base_price)      AS avg_selling_price,
    ROUND(COALESCE(SUM(oi.total), 0) /
        NULLIF(p.view_count, 0), 4)                 AS revenue_per_view,
    ROUND(p.purchase_count::NUMERIC /
        NULLIF(p.view_count, 0) * 100, 2)           AS purchase_rate_pct
FROM catalog.products p
LEFT JOIN commerce.order_items oi ON oi.product_id = p.product_id
LEFT JOIN commerce.orders o ON o.order_id = oi.order_id
    AND o.status NOT IN ('cancelled','refunded')
GROUP BY p.product_id, p.store_id, p.name, p.base_price,
         p.avg_rating, p.review_count, p.view_count, p.purchase_count;

-- View: Clientes em risco de churn
CREATE OR REPLACE VIEW analytics.v_churn_risk_customers AS
SELECT
    c.customer_id,
    c.store_id,
    c.email,
    c.first_name,
    c.last_name,
    cf.days_since_last_order,
    cf.days_since_last_visit,
    cf.total_orders,
    cf.total_spent,
    cf.churn_probability,
    cf.churn_risk_level,
    cf.customer_health_score,
    cf.predicted_ltv_365d,
    cf.avg_order_value
FROM core.customers c
INNER JOIN ml.customer_features cf
    ON cf.customer_id = c.customer_id AND cf.store_id = c.store_id
WHERE cf.churn_risk_level IN ('high','critical')
ORDER BY cf.churn_probability DESC;

-- ============================================================
-- FUNÇÕES UTILITÁRIAS
-- ============================================================

-- Função: Atualiza timestamp updated_at automaticamente
CREATE OR REPLACE FUNCTION core.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Triggers de updated_at
CREATE TRIGGER trg_customers_updated_at
    BEFORE UPDATE ON core.customers
    FOR EACH ROW EXECUTE FUNCTION core.set_updated_at();

CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON catalog.products
    FOR EACH ROW EXECUTE FUNCTION core.set_updated_at();

CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON commerce.orders
    FOR EACH ROW EXECUTE FUNCTION core.set_updated_at();

CREATE TRIGGER trg_carts_updated_at
    BEFORE UPDATE ON commerce.carts
    FOR EACH ROW EXECUTE FUNCTION core.set_updated_at();

-- Função: Calcula score de popularidade do produto
CREATE OR REPLACE FUNCTION catalog.calc_popularity_score(
    p_views BIGINT,
    p_purchases BIGINT,
    p_rating NUMERIC,
    p_reviews INT,
    p_wishlist INT
) RETURNS NUMERIC AS $$
BEGIN
    RETURN (
        (COALESCE(p_views, 0) * 0.2) +
        (COALESCE(p_purchases, 0) * 3.0) +
        (COALESCE(p_rating, 0) * COALESCE(p_reviews, 0) * 1.5) +
        (COALESCE(p_wishlist, 0) * 0.5)
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Função: Classifica risco de churn
CREATE OR REPLACE FUNCTION ml.classify_churn_risk(prob NUMERIC)
RETURNS VARCHAR AS $$
BEGIN
    RETURN CASE
        WHEN prob >= 0.75 THEN 'critical'
        WHEN prob >= 0.50 THEN 'high'
        WHEN prob >= 0.25 THEN 'medium'
        ELSE 'low'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================
-- DADOS INICIAIS (SEED)
-- ============================================================

INSERT INTO core.stores (store_code, store_name, store_slug, domain, currency)
VALUES
    ('LOJA_A', 'Loja Alpha', 'loja-alpha', 'www.lojaalpha.com.br', 'BRL'),
    ('LOJA_B', 'Loja Beta', 'loja-beta',  'www.lojabeta.com.br',  'BRL');

INSERT INTO admin.admin_users (email, password_hash, salt, full_name, role)
VALUES
    ('superadmin@sistema.com', 'HASH_AQUI', 'SALT_AQUI', 'Super Administrador', 'superadmin');

-- ============================================================
-- COMENTÁRIOS NAS TABELAS PRINCIPAIS
-- ============================================================

COMMENT ON TABLE core.customers IS 'Clientes das lojas virtuais com dados demográficos e scores de ML';
COMMENT ON TABLE analytics.events IS 'Stream de eventos de comportamento do usuário — base principal para ML';
COMMENT ON TABLE ml.customer_features IS 'Feature store: todas as features calculadas por cliente para modelos de ML';
COMMENT ON TABLE ml.predictions IS 'Log de predições dos modelos para monitoramento e re-treinamento';
COMMENT ON TABLE analytics.searches IS 'Histórico de buscas para análise de intenção e recomendação';
COMMENT ON COLUMN analytics.events.properties IS 'Dados dinâmicos do evento: ex product_view={product_id, price, category}';
COMMENT ON COLUMN ml.customer_features.rfm_segment IS 'Champions, Loyal, Potential Loyal, New, At Risk, Cant Lose, Lost';
