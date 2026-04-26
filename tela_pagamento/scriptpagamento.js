// Máscara do Cartão
const cardInput = document.getElementById('card-number');
cardInput.addEventListener('input', (e) => {
    let v = e.target.value.replace(/\D/g, '');
    v = v.match(/.{1,4}/g)?.join(' ') || '';
    e.target.value = v;
});

// Feedback de Sucesso
document.getElementById('payment-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const btn = document.querySelector('.btn-main');
    
    btn.innerText = "Processando...";
    btn.style.opacity = "0.7";
    
    setTimeout(() => {
        alert("Obrigado! Seu projeto Vetro Vivo foi iniciado com sucesso.");
        window.location.href = "index.html";
    }, 2000);
});