document.getElementById('loginForm').addEventListener('submit', async function(e) {
    e.preventDefault();

    const btn = document.getElementById('btnLogin');
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;

    // Feedback visual de carregamento
    const originalText = btn.innerHTML;
    btn.innerHTML = "Entrando...";
    btn.style.opacity = "0.7";
    btn.style.cursor = "wait";

    try {
        // Chamada para o backend C#
        const response = await fetch('http://localhost:5000/api/auth/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                email: email,
                password: password
            })
        });

        const data = await response.json();

        if (response.ok) {
            console.log("Login bem-sucedido:", data);
            
            // Salva o token ou info do usuário (opcional)
            localStorage.setItem('userEmail', data.email);
            
            // Redireciona para a home
            window.location.href = "../tela_inicial/index.html"; 
        } else {
            // Caso o backend retorne erro (401 Unauthorized, etc)
            alert(data.message || "Erro ao realizar login.");
            resetButton(btn, originalText);
        }

    } catch (error) {
        console.error("Erro na conexão:", error);
        alert("Não foi possível conectar ao servidor. Verifique se o backend está rodando.");
        resetButton(btn, originalText);
    }
});

function resetButton(btn, text) {
    btn.innerHTML = text;
    btn.style.opacity = "1";
    btn.style.cursor = "pointer";
}

// Alerta para o "Esqueci a senha"
document.getElementById('forgotPassword').addEventListener('click', function(e) {
    e.preventDefault();
    alert("Funcionalidade em desenvolvimento. Por favor, contacte o administrador.");
});