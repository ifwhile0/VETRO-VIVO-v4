// Lógica de Filtros
const filterBtns = document.querySelectorAll('.filter-btn');

filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        // Remove classe ativa de todos
        filterBtns.forEach(b => b.classList.remove('active'));
        // Adiciona ao clicado
        btn.classList.add('active');
        
        console.log("Filtro selecionado: " + btn.innerText);
    });

function atualizarCarrinho() {
    const lista = document.getElementById('lista-itens');
    const totalElemento = document.getElementById('total-cart');
    const badge = document.getElementById('cart-count'); // Seleciona o contador da navbar
    
    lista.innerHTML = '';
    total = 0;

    carrinho.forEach((item, index) => {
        total += item.preco;
        lista.innerHTML += `
            <div class="item-row">
                <span>${item.nome}</span>
                <span>R$ ${item.preco.toFixed(2)} 
                    <button class="btn-remover" onclick="remover(${index})">x</button>
                </span>
            </div>
        `;
    });

    totalElemento.innerText = `R$ ${total.toFixed(2)}`;
    
    // Atualiza o contador na navbar
    if (carrinho.length > 0) {
        badge.innerText = carrinho.length;
        badge.style.display = 'block';
    } else {
        badge.style.display = 'none';
    }
}

});

// Mensagem de boas-vindas no console
console.log("Vetro Vivo - Loja carregada com sucesso!");