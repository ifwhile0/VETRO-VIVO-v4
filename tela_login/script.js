// Lógica de envio do formulário
document.getElementById('loginForm').addEventListener('submit', function(e) {
    e.preventDefault();

    const btn = document.getElementById('btnLogin');
    const email = document.getElementById('email').value;

    // Feedback visual
    btn.innerHTML = "Entrando...";
    btn.style.opacity = "0.7";
    btn.style.cursor = "wait";

    console.log("Tentativa de login para:", email);

    // Simula um pequeno carregamento antes de ir para a home
    setTimeout(() => {
        window.location.href = "index.html"; 
    }, 1200);
});

// Alerta simples para o "Esqueci a senha"
document.getElementById('forgotPassword').addEventListener('click', function(e) {
    e.preventDefault();
    alert("Enviamos um link de recuperação para o seu e-mail!");
});