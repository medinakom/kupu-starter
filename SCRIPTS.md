# Kupu Starter Scripts Manual

This manual provides detailed usage instructions for the automation scripts available in the `kupu-starter/scripts` directory. These scripts accelerate development by generating boilerplate code for modules, pages, entities, roles, and relationships.

## 📋 Quick Reference

| Script | Purpose |
|--------|---------|
| `create-module.sh` | Create a new application module. |
| `create-page.sh` | Generate a new blank page. |
| `create-entity-view.sh` | Generate a full CRUD stack for an entity. |
| `create-role-view.sh` | Generate a generic PartyRole implementation. |
| `create-person-role.sh` | Generate a Person-specific role. |
| `create-relationship-view.sh` | Generate a relationship between two roles (with lazy selectors). |
| `delete-entity-view.sh` | Delete an entity and all its generated files. |
| `delete-relationship-view.sh` | Delete a relationship and its generated files. |
| `generate-persistence.sh` | Update `persistence.xml` with all entities. |

---

## 🏗️ Module & Page Management

### Create a Module
Generates a new module structure under `src/main/java/.../app/<module>` and registers it.

**Usage:**
```bash
./create-module.sh <module_name>
```

**Example:**
```bash
./create-module.sh inventory
```

### Create a Page
Generates a new page controller and XHTML view.

**Usage:**
```bash
./create-page.sh <module_name> <PageClassName>
```

**Example:**
```bash
./create-page.sh inventory Dashboard
```
*Generates `DashboardPage.java` and `dashboard.xhtml`.*

---

## 📦 Entity Management

### Create an Entity (CRUD)
Generates a complete CRUD stack: Entity, Facade, Page, Editor, List, Filter, Converter, and XHTMLs.

**Usage:**
```bash
./create-entity-view.sh <module> <EntityName> <full.package.path>
```

**Example:**
```bash
./create-entity-view.sh inventory Product id.my.mdn.kupu.app.inventory.entity
```

### Delete an Entity
Completely removes an entity and all associated files (Java, XHTML, ACLs).

**Usage:**
```bash
./delete-entity-view.sh <module> <EntityName> [--force]
```

**Example:**
```bash
./delete-entity-view.sh inventory Product --force
```

---

## 👥 Role Management

### Create a Generic Role
Generates a `PartyRole` implementation that can be assigned to either a Person or Organization.

**Usage:**
```bash
./create-role-view.sh <module> <RoleName> <Type>
```
*   `Type`: `Person`, `Organization`, or `Both` (defaults to Both).

**Example:**
```bash
./create-role-view.sh hr Employee Both
```

### Create a Person Role
Wrapper for creating a role specifically for Persons.

**Usage:**
```bash
./create-person-role.sh <module> <RoleName>
```

**Example:**
```bash
./create-person-role.sh santri Ustadz
```

---

## 🔗 Relationship Management

### Create a Relationship
Generates a `PartyRelationship` entity connecting two roles, along with a refined editor interface.

**Key Features:**
*   **Lazy Selectors**: Automatically generates efficient `LazyList` and `LazyChooser` components for the roles if they don't exist.
*   **Refined UI**: Uses a centered form layout (`formlet`) and includes a "Reset End Date" button.

**Usage:**
```bash
./create-relationship-view.sh <module> <RelationshipName> <FromRole> <ToRole>
```

**Example:**
```bash
./create-relationship-view.sh santri Pengasuhan KelompokPengasuhan Santri
```
*Creates `Pengasuhan` relationship where `KelompokPengasuhan` is the "From" role (source) and `Santri` is the "To" role (target).*

### Delete a Relationship
Removes a relationship and its associated components.

**Usage:**
```bash
./delete-relationship-view.sh [-c] <module> <RelationshipName> [FromRole] [ToRole]
```

**Options:**
*   `-c`: **Complete Cleanup**. Attempts to remove the associated `LazyList` and `LazyChooser` components for the roles.
    *   **Safety Check**: The script will *skip* deletion if it detects that the lazy component is used by other views.

**Example:**
```bash
./delete-relationship-view.sh -c santri Pengasuhan KelompokPengasuhan Santri
```

---

## 🛠️ Utilities

### Generate Persistence
Scans the project for `@Entity` classes and updates `persistence.xml`. run this if you encounter "Unknown Entity" errors.

**Usage:**
```bash
./generate-persistence.sh
```

### Create Config JAR
Regenerates `kupu-config.jar` with fresh configuration files (`beans.xml`, `persistence.xml`, `web.xml`).

**Usage:**
```bash
./create-config-jar.sh
```
