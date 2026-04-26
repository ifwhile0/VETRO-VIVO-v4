document.addEventListener('DOMContentLoaded', () => {
    const cards = document.querySelectorAll('.price-card');

    // Efeito suave de entrada nos cards
    cards.forEach((card, index) => {
        card.style.opacity = '0';
        card.style.transform = 'translateY(20px)';
        
        setTimeout(() => {
            card.style.transition = 'all 0.6s ease';
            card.style.opacity = '1';
            card.style.transform = 'translateY(0)';
        }, 200 * index);
    });

    // Log para ajudar seus amigos na integração
    console.log("Módulo de Manutenção Vetro Vivo carregado com sucesso.");
});