document.addEventListener('DOMContentLoaded', () => {
    // 1. Pega o tipo de projeto que vem da URL (ex: orcamento.html?tipo=salgada)
    const params = new URLSearchParams(window.location.search);
    const tipo = params.get('tipo');
    
    if(tipo) {
        document.getElementById('projectType').value = tipo;
    }

    // 2. Impede datas retroativas no calendário
    const dateField = document.getElementById('visitDate');
    const today = new Date().toISOString().split('T')[0];
    dateField.setAttribute('min', today);

    // 3. Simulação de envio
    document.getElementById('mainBudgetForm').addEventListener('submit', (e) => {
        e.preventDefault();
        alert('Solicitação enviada com sucesso! Nossa equipe entrará em contato em breve.');
        window.location.href = 'index.html';
    });
});