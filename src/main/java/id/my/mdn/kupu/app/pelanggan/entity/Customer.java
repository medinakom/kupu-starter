package id.my.mdn.kupu.app.pelanggan.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.util.Objects;

@Entity
@Table(name = "PELANGGAN_CUSTOMER")
public class Customer implements Serializable {

    private static final long serialVersionUID = 1L;

    @Id
    private Long id;

    private String name;

    @ManyToOne
    private TariffCategory tariffCategory;

    private String rt;

    private String rw;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public TariffCategory getTariffCategory() {
        return tariffCategory;
    }

    public void setTariffCategory(TariffCategory tariffCategory) {
        this.tariffCategory = tariffCategory;
    }

    public String getRt() {
        return rt;
    }

    public void setRt(String rt) {
        this.rt = rt;
    }

    public String getRw() {
        return rw;
    }

    public void setRw(String rw) {
        this.rw = rw;
    }

    @Override
    public int hashCode() {
        int hash = 7;
        hash = 97 * hash + Objects.hashCode(this.id);
        return hash;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (obj == null || getClass() != obj.getClass()) return false;
        final Customer other = (Customer) obj;
        return Objects.equals(this.id, other.id);
    }

    @Override
    public String toString() {
        return id != null ? String.valueOf(id) : null;
    }
}
